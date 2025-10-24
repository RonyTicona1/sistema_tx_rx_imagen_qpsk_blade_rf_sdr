%% ============================================================
%% RX QPSK FINAL
% Recepción de imagen mediante QPSK (π/4, Gray)
%% ============================================================

% Archivo de entrada por defecto (editar si es necesario)
rutaScDefecto = 'P3ruebaFF2.sc16q11';
rx_qpsk_final(rutaScDefecto);


%% ============================================================
function img = rx_qpsk_final(inSc16)
%% ============================================================

t0 = tic;   % cronómetro simple

% Respaldo si no se pasa argumento
if nargin < 1 || isempty(inSc16)
    inSc16 = 'anims_test.sc16q11';
end

% Parámetros principales (deben coincidir con TX)
sps     = 8;        % muestras por símbolo
rolloff = 0.35;     % roll-off del filtro RRC
span    = 10;       % longitud del filtro (en símbolos)
fase0   = pi/4;     % desplazamiento de fase QPSK

lenBarker = 13; 
repBarker = 2; 
Lpre      = lenBarker * repBarker;   % longitud total del preámbulo
Ntrain    = 64;                      % símbolos de entrenamiento (QPSK)
HDR_BITS  = 56;                      % 16+16+8+16

% ===== 1) Cargar y normalizar =====
rx = double(load_sc16q11(inSc16)); 
rx = rx(:);
rx = rx - mean(rx);                 % elimina DC
rx = rx / max(1e-12, rms(rx));      % normaliza en potencia

% ===== Gráfica de la señal real en el tiempo =====  (1/5) [mantener tal cual]
figure('Name','Señal real en el tiempo');
plot(real(rx),'-'); grid on;
xlabel('Índice de muestra'); ylabel('Amplitud (Re\{x[n]\})');
title('Señal recibida - parte real');

% ===== 2) Filtro RRC =====
rrcRx = comm.RaisedCosineReceiveFilter('Shape','Square root', ...
    'RolloffFactor', rolloff, 'FilterSpanInSymbols', span, ...
    'InputSamplesPerSymbol', sps, 'DecimationFactor', 1);
rx_f = rrcRx([rx; zeros(span*sps,1)]);
rx_f = rx_f(span*sps+1:end);

% ===== 3) Sincronía de símbolos (Zero-Crossing) =====
symSync = comm.SymbolSynchronizer( ...
  'TimingErrorDetector','Zero-Crossing (decision-directed)', ...
  'SamplesPerSymbol', sps, 'DampingFactor', 1.0, ...
  'NormalizedLoopBandwidth', 0.006);
rx_sym = symSync(rx_f);  % salida a 1 sps

% ===== 4) Detección del Barker =====
objBarker  = comm.BarkerCode('Length', lenBarker, 'SamplesPerFrame', lenBarker);
bitsBarker = (1 + objBarker())/2;
preBits    = repmat(bitsBarker, repBarker, 1);
simPre     = pskmod(preBits, 2, 0);                      % BPSK
c          = filter(flipud(conj(simPre)), 1, rx_sym);    % correlación
[pk,ix]    = max(abs(c));
startPre   = ix - Lpre + 1;
if startPre < 1
    error('No se detectó el Barker.');
end

% ===== Correlación con Barker =====  (2/5)
try
    figure('Name','Correlación Barker','Color','w');
    Ncorr = min(length(c));                 % muestra razonable
    plot(abs(c(1:Ncorr)),'-'); grid on;
    xlabel('Índice (símbolos)'); ylabel('|correlación|');
    title(sprintf('Correlación con preámbulo Barker (pico @ %d)', startPre));
catch
end

% ===== 5) Corrección de CFO y fase usando el preámbulo =====
z     = rx_sym(startPre:startPre+Lpre-1) .* conj(simPre);
phi   = unwrap(angle(z(:))).'; 
k     = 0:Lpre-1; 
p     = polyfit(k, phi, 1);
alpha = p(1); 
beta  = p(2);
m     = (0:length(rx_sym)-startPre).';
rx_fix = rx_sym(startPre:end) .* exp(-1j*(alpha*m + beta));

% ===== 6) Refinamiento CFO/fase con entrenamiento QPSK =====
patron16         = pskmod([0;1;2;3; 1;0;3;2; 2;3;0;1; 3;2;1;0], 4, fase0, 'gray');
simEntrenamiento = repmat(patron16, 4, 1);
rEntrenamiento   = rx_fix(Lpre + (1:Ntrain));

best = struct('var', inf, 'conj', false, 'a', 0, 'b', 0);
for cc = [false true]
    t  = rEntrenamiento; 
    if cc, t = conj(t); end
    ph = unwrap(angle(t .* conj(simEntrenamiento)));
    k  = 0:Ntrain-1; 
    p  = polyfit(k, ph.', 1);
    v  = var(ph.' - polyval(p, k));                % varianza como métrica
    if v < best.var
        best = struct('var', v, 'conj', cc, 'a', p(1), 'b', p(2));
    end
end

rDespues = rx_fix(Lpre+Ntrain+1:end);
if best.conj, rDespues = conj(rDespues); end
n = (0:numel(rDespues)-1).';
rDespues = rDespues .* exp(-1j*(best.a*n + best.b));

% ===== Constelación antes de corrección (CFO/fase) =====  (3/5)
try
    figure('Name','Constelación - antes de corrección','Color','w');
    i0 = max(1, startPre-4000);
    i1 = min(length(rx_sym), startPre+Lpre+4000);
    plot(real(rx_sym(i0:i1)), imag(rx_sym(i0:i1)), '.'); 
    axis equal; grid on;
    xlabel('I'); ylabel('Q');
    title('Antes de corrección (alrededor del preámbulo)');
catch
end

% ===== Constelación después de refinamiento (CFO/fase) =====  (4/5)
try
    figure('Name','Constelación - después de refinamiento','Color','w');
    M = min(12000, numel(rDespues));
    plot(real(rDespues(1:M)), imag(rDespues(1:M)), '.');
    axis equal; grid on;
    xlabel('I'); ylabel('Q');
    title('Después de refinamiento (CFO/fase)');
catch
end

% ===== 7) Lectura del header {rotación, slip} =====
segN = min(numel(rDespues), 200000);
phiC = [0, pi/2, pi, 3*pi/2]; 
slipC = 0:3;
ok=false; bestH=0; bestW=0; bestC=0; rotSel=0; slipSel=0;

for ss = slipC
    if 1+ss > segN, continue; end
    s = rDespues(1+ss:segN);
    for rr = 1:numel(phiC)
        sy   = s .* exp(-1j*phiC(rr));
        b    = pskdemod(sy, 4, fase0, 'gray', 'OutputType', 'bit');
        bits = b(:).';
        if numel(bits) < HDR_BITS, continue; end
        hdr  = bits(1:HDR_BITS);
        H    = bi2de(hdr(1:16) ,'left-msb');
        W    = bi2de(hdr(17:32),'left-msb');
        C    = bi2de(hdr(33:40),'left-msb');
        okcrc= isequal(crc16(hdr(1:40)), hdr(41:56));
        if okcrc && H>=1 && H<=8192 && W>=1 && W<=8192 && ismember(C,[1,3])
            ok=true; bestH=H; bestW=W; bestC=C; rotSel=phiC(rr); slipSel=ss; break;
        end
    end
    if ok, break; end
end

if ~ok
    error('Cabecera inválida o no detectada.');
end

% ===== 8) Alineamiento del payload =====
s_all = rDespues(1+slipSel:end) .* exp(-1j*rotSel);

% ===== 9) PLL + ajuste final de fase (snap π/4) =====
carSync2 = comm.CarrierSynchronizer('Modulation','QPSK', ...
  'ModulationPhaseOffset','Custom','CustomPhaseOffset', fase0, ...
  'SamplesPerSymbol', 1, 'DampingFactor', 0.707, ...
  'NormalizedLoopBandwidth', 0.001);
s_all = carSync2(s_all);

K = min(3000, numel(s_all));
phi_meas = angle(mean(s_all(1:K).^4))/4;
kpi2 = round((phi_meas - fase0)/(pi/2));
phi_fix = phi_meas - (fase0 + kpi2*(pi/2));
s_all = s_all .* exp(-1j*phi_fix);

% ===== 10) Demodulación, descramble y reconstrucción de imagen =====
b_all   = pskdemod(s_all, 4, fase0, 'gray', 'OutputType', 'bit'); 
b_all   = b_all(:).';
imgBits = b_all(HDR_BITS+1:end);
imgBits = lfsr_descramble(imgBits, 127);

needBytes = double(bestH)*double(bestW)*double(max(1,bestC));
needBits  = needBytes*8;

if numel(imgBits) < needBits
    imgBits(end+1:needBits) = 0; 
else
    imgBits = imgBits(1:needBits);
end

bytes = uint8(bi2de(reshape(imgBits,8,[]).','left-msb'));

if bestC == 1
    img = reshape(bytes,[bestH bestW]);
else
    img = reshape(bytes,[bestH bestW bestC]);
end

% ===== Resumen en consola (práctica 3) =====
total_sym = Lpre + Ntrain + numel(s_all);   % aprox. símbolos procesados

fprintf('\n=== RECEPCIÓN QPSK ===\n');
fprintf(' Archivo:        %s\n', inSc16);
fprintf(' Imagen:         %dx%dx%d (alto×ancho×canales)\n', bestH, bestW, bestC);
fprintf(' PHY:            SPS=%d | rolloff=%.2f | span=%d | fase=%.2f rad\n', sps, rolloff, span, fase0);
fprintf(' Preambulo:      start=%d | métrica=%.2f\n', startPre, pk);
fprintf(' CFO/fase:       alpha=%.3e rad/sym | beta=%.3f rad\n', alpha, beta);
fprintf(' Ajustes:        conj=%d | rot=%.2f rad | slip=%d\n', best.conj, rotSel, slipSel);
fprintf(' Símbolos:       pre=%d | train=%d | total≈%d\n', Lpre, Ntrain, total_sym);
fprintf(' Muestras RX:    %d\n', numel(rx));
fprintf(' Datos:          HDR=%d bits | payload=%d bytes\n', HDR_BITS, numel(bytes));
fprintf(' Tiempo:         %.3f s\n', toc(t0));
fprintf('=======================\n\n');

% ===== Mostrar resultados =====
figure('Name','Imagen QPSK Reconstruida en Rx'); 
imshow(img);
title(sprintf('Imagen QPSK Reconstruida en Rx (%dx%dx%d)', bestH, bestW, bestC));

% ===== Constelación payload (final) =====  (5/5)
try
    figure('Name','Constelación - payload final','Color','w'); 
    M = min(16000, numel(s_all));
    plot(real(s_all(1:M)), imag(s_all(1:M)), '.');
    axis equal; grid on;
    xlabel('I'); ylabel('Q');
    title('Payload tras PLL + snap π/4');
catch
end
end


% ===== Funciones auxiliares =====
function bitsOut = lfsr_descramble(bitsIn, seed)
s = de2bi(seed,7,'left-msb'); 
s = s(:).';
bitsOut = false(size(bitsIn));
for n = 1:numel(bitsIn)
    fb = xor(s(4), s(7));
    bitsOut(n) = xor(bitsIn(n), fb);
    s = [fb s(1:6)];
end
end

function crc = crc16(bits)
crcReg = uint16(hex2dec('FFFF'));
for i = 1:numel(bits)
  inbit  = logical(bits(i)); 
  xorbit = bitget(crcReg,1) ~= inbit;
  crcReg = bitshift(crcReg, -1);
  if xorbit, crcReg = bitxor(crcReg, hex2dec('A001')); end
end
crc = de2bi(crcReg,16,'left-msb');
end