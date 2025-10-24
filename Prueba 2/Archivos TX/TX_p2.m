%% ============================================================
%% TX QPSK FINAL
% Transmisión de imagen mediante modulación QPSK (π/4, Gray)
%% ============================================================

rutaImgDefecto = 'rey.png';
rutaOutDefecto = 'P3PruebaFF2.sc16q11';
tx_qpsk_final(rutaImgDefecto, rutaOutDefecto);


%% ============================================================
function tx_qpsk_final(rutaImg, rutaOutSc16)

t0 = tic;  % cronómetro para medir ejecución
%% ============================================================

% Parámetros del sistema
sps     = 8;      % muestras por símbolo
rolloff = 0.35;   % roll-off del filtro RRC
span    = 10;     % longitud del filtro en símbolos
fase0   = pi/4;   % desfase QPSK (igual al RX)

% Lectura de imagen
[img, alto, ancho, canales] = load_image_uint8_1or3(rutaImg);
bytesImagen = typecast(img(:), 'uint8');

% Cabecera con CRC16
bitsHdr = [ ...
    de2bi(uint16(alto),   16, 'left-msb'), ...   % alto (16 bits)
    de2bi(uint16(ancho),  16, 'left-msb'), ...   % ancho (16 bits)
    de2bi(uint8(canales),  8, 'left-msb')  ...   % canales (8 bits)
];
crcHdr  = crc16(bitsHdr);                        % cálculo CRC16
bitsHdr = [bitsHdr, crcHdr];                     % header completo (56 bits)

% Payload con scrambler LFSR (7 bits)
bitsPay = reshape(de2bi(bytesImagen, 8, 'left-msb').', [], 1).';  % imagen a bits
bitsPay = lfsr_scramble(bitsPay, 127);                            % aplica scrambler

% Preambulo Barker-13×2 (BPSK)
lenBarker = 13; repBarker = 2;                                     % longitud y repeticiones
objBarker  = comm.BarkerCode('Length', lenBarker, 'SamplesPerFrame', lenBarker);
bitsBarker = (1 + objBarker())/2;                                  % [0,1] en vez de [-1,1]
simPre     = pskmod(repmat(bitsBarker, repBarker, 1), 2, 0);       % modulación BPSK

% Entrenamiento QPSK (64 símbolos conocidos)
patron16         = pskmod([0;1;2;3; 1;0;3;2; 2;3;0;1; 3;2;1;0], 4, fase0, 'gray'); % patrón base
simEntrenamiento = repmat(patron16, 4, 1);                                          % 16x4 = 64 símbolos

% Mapeo QPSK (Gray, π/4)
mapear2sim = @(bits) pskmod(bi2de(reshape(bits, 2, []).', 'left-msb'), 4, fase0, 'gray'); % función mapeo
simHdr     = mapear2sim(bitsHdr);      % header a símbolos
simPay     = mapear2sim(bitsPay);      % payload a símbolos

% Construcción completa de la señal
todosSimbolos = [simPre; simEntrenamiento; simHdr; simPay];         % concatenación final

% Filtro RRC (transmisor)
filtroTX = comm.RaisedCosineTransmitFilter( ...
    'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, ...
    'OutputSamplesPerSymbol', sps);
senalTX = filtroTX([todosSimbolos; zeros(span,1)]);                 % filtrado + retardo
senalTX = senalTX ./ max(abs(senalTX));                             % normalización

% Guardar señal en formato .sc16q11
if nargin < 2 || isempty(rutaOutSc16)
    rutaOutSc16 = 'transmision_qpsk.sc16q11';
end
save_sc16q11(rutaOutSc16, senalTX);

% --- Resumen para Command Window ---
tamBytes = 0;
try
    infoOut = dir(rutaOutSc16);
    if ~isempty(infoOut), tamBytes = infoOut.bytes; end
catch
end

% Formato de tamaño legible
if tamBytes >= 2^20
    tamTxt = sprintf('%.2f MB', tamBytes/2^20);
elseif tamBytes >= 2^10
    tamTxt = sprintf('%.2f KB', tamBytes/2^10);
elseif tamBytes > 0
    tamTxt = sprintf('%d bytes', tamBytes);
else
    tamTxt = 'N/D';
end

duracion = toc(t0);

fprintf('\n=== TRANSMISIÓN QPSK COMPLETADA ===\n');
fprintf(' Imagen:          %s\n', rutaImg);
fprintf(' Salida:          %s\n', rutaOutSc16);
fprintf(' Dimensiones:     %dx%dx%d (alto×ancho×canales)\n', alto, ancho, canales);
fprintf(' Parámetros PHY:  SPS=%d | rolloff=%.2f | span=%d | fase=%.2f rad\n', sps, rolloff, span, fase0);
fprintf(' Símbolos:        total=%d | pre=%d | train=%d | hdr=%d | pay=%d\n', ...
        numel(todosSimbolos), numel(simPre), numel(simEntrenamiento), numel(simHdr), numel(simPay));
fprintf(' Muestras TX:     %d (incluye cola del filtro: %d)\n', numel(senalTX), span);
fprintf(' Normalización:   pico=1.00 (aplicada)\n');
fprintf(' Archivo SC16:    %s\n', tamTxt);
fprintf(' Tiempo total:    %.3f s\n', duracion);
fprintf('====================================\n\n');

% ===== Gráfica de Constelación TX =====
try
    figure('Name','Constelación TX');  % fondo blanco
    hold on;

    % Muestra solo training + 500 símbolos de payload
    plot(real(simEntrenamiento), imag(simEntrenamiento), 'ro', 'MarkerFaceColor','r', 'DisplayName','Entrenamiento');
    plot(real(simHdr), imag(simHdr), 'bs', 'MarkerFaceColor','b', 'DisplayName','Header');
    plot(real(simPay(1:500)), imag(simPay(1:500)), 'k.', 'DisplayName','Payload');

    axis equal;
    grid on;
    xlabel('In-Phase (I)');
    ylabel('Quadrature (Q)');
    title('Constelación Transmisor QPSK (π/4, Gray)');
    legend('Location','northeastoutside');
    xlim([-1.2 1.2]); ylim([-1.2 1.2]);
    hold off;
catch
end
end


%% ============================================================
% FUNCIONES AUXILIARES
%% ============================================================

function [img, H, W, C] = load_image_uint8_1or3(ruta)
info = imfinfo(ruta);
[A, mapa, alfa] = imread(ruta); %#ok<ASGLU>

if ~isempty(mapa)
    A = ind2rgb(A, mapa);                     % indexado → RGB
end
if ndims(A) == 3 && size(A,3) == 4
    A = A(:,:,1:3);                           % elimina canal alfa
end
if ~isa(A,'uint8')
    A = im2uint8(A);                          % asegura tipo uint8
end
if isfield(info,'Orientation')
    switch info.Orientation
        case 1
        case 2, A = fliplr(A);
        case 3, A = rot90(A,2);
        case 4, A = flipud(A);
        case 5, A = rot90(flipud(A),1);
        case 6, A = rot90(A,-1);
        case 7, A = rot90(flipud(A),-1);
        case 8, A = rot90(A,1);
    end
end

img = A; H = size(A,1); W = size(A,2); C = size(A,3);
if isempty(C), C = 1; end
end


function bitsOut = lfsr_scramble(bitsIn, semilla)
% Scrambler LFSR de 7 bits (1 + x^4 + x^7)
s = de2bi(semilla, 7, 'left-msb'); s = s(:).';
bitsOut = false(size(bitsIn));
for n = 1:numel(bitsIn)
    fb = xor(s(4), s(7));               % realimenta s4 y s7
    bitsOut(n) = xor(bitsIn(n), fb);    % aplica XOR al bit de entrada
    s = [fb s(1:6)];                    % avanza registro
end
end


function crc = crc16(bits)
% CRC-16-IBM (poly 0xA001, init 0xFFFF)
crcReg = uint16(hex2dec('FFFF'));
for i = 1:numel(bits)
    inbit  = logical(bits(i));
    xorbit = bitget(crcReg,1) ~= inbit;
    crcReg = bitshift(crcReg, -1);
    if xorbit
        crcReg = bitxor(crcReg, hex2dec('A001'));
    end
end
crc = de2bi(crcReg, 16, 'left-msb');
end