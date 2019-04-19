function features = extractFeatures_v1(ecog, fs)

M = @(x) mean(x);
features = zeros(5998, 62);

% compute average time domain voltage for each channel
for i = 1:size(ecog, 2)
    avVoltage = MovingWinFeats(ecog(:,i), fs, 100e-3, 50e-3, M);
    features(:, i) = avVoltage';
end 

% compute average frequency domain magnitude within bands 
bands = [5 15; 20 25; 75 115; 125 160; 160 175];
for i = 1:size(bands, 1)
    b = bands(i, :);
    band_diff = b(2) - b(1);
    Nfft = length(ecog) * 100 * (10/band_diff);
    frequency = ((0:1/Nfft:1-1/Nfft)*fs).';
    for j = 1:size(ecog, 2)
        signal = ecog(:,i);
        f = fft(signal,Nfft);
        mag = abs(f);
        band_inds = frequency >= b(1) & frequency <= b(2);
        avFreq = MovingWinFeats(mag(band_inds), fs, 100e-3, 50e-3, M);
        disp([num2str(i) ' ' num2str(j) ' ' num2str(length(avFreq))])
        features(:, end+1) = avFreq(1:5998)';
    end 
end 

end 