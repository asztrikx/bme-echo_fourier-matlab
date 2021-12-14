%addEffect("pavarotti_original.wav", "impresp_mono.wav", "pavarotti_conv.wav", false);
%simulateRealTime("pavarotti_original.wav", "impresp_mono.wav", "pavarotti_conv.wav", 64);
addEffectToMic("impresp_mono.wav", 1024, 44100);

function simulateRealTime(srcInp, srcImpresp, srcOutp, chunkSize)
    % read
    [inp, inpSampleRate] = audioread(srcInp);
    [impresp, imprespSampleRate] = audioread(srcImpresp);
    
    % resample
    inpResampled = resample(inp, imprespSampleRate, inpSampleRate);
    inpResampledSampleRate = imprespSampleRate;

    % set size to the output of time domain convolution to avoid circular property of ifft
    % set size to be a power of 2
    nfft = 2^nextpow2(chunkSize + length(impresp) - 1);

    % cache FFT of impresp
    imprespFFT = fft(impresp, nfft);

    % outside visibility of outp, overlap
    outp = zeros(0,1);
    outpSampleRate = imprespSampleRate;
    overlap = zeros(0,1);

    % padding to chunkSize (easier to handle)
    inpResampled = paddingZeroMultiple(inpResampled, chunkSize);

    % split to chunks
    tic
    for idx = 1:chunkSize:length(inpResampled)
        from = idx;
        to = idx + chunkSize - 1;
        chunk = inpResampled(from:to);

        [chunkOutp, overlap] = addEffectToChunk(chunk, imprespFFT, nfft, chunkSize, overlap);

        outp = [outp; chunkOutp];
    end
    toc

    % append remaining overlap
    outp = [outp; overlap];

    % cut padding
    outpLength = length(inpResampled) + length(impresp) - 1;
    outp = outp(1:outpLength);

    % rescale
    outp = rescale(outp, min(inpResampled), max(inpResampled), min(outp), max(outp));

    % write
    audiowrite(srcOutp, outp, outpSampleRate);
end

% overlap-add algorithm
function [chunkOutp, overlap] = addEffectToChunk(chunk, imprespFFT, nfft, chunkSize, overlap)
    if length(overlap) == 0
        % overlap should be at least chunkSize + 1
        % being multiple of chunkSize makes it easier to work with
        overlap = zeros(chunkSize * 2, 1);
    end

    x = ifft(fft(chunk, nfft) .* imprespFFT);
    chunkOutp = x(1:chunkSize) + overlap(1:chunkSize);
    overlap = overlap(chunkSize+1:end);
    xRemainer = x(chunkSize+1:end);
    xRemainderSize = length(xRemainer);
    overlap = paddingZero(overlap, xRemainderSize) + xRemainer;
    overlap = paddingZeroMultiple(overlap, chunkSize);
end

function data = paddingZeroMultiple(data, n)
    data = [data; zeros(n - mod(length(data), n), 1)];
end

function data = paddingZero(data, size)
    if length(data) > size 
        disp("wrong param");
    end
    data = [data; zeros(size - length(data), 1)];
end

% final
function addEffect(srcInp, srcImpresp, srcOutp, shouldConv)
    % read
    [inp, inpSampleRate] = audioread(srcInp);
    [impresp, imprespSampleRate] = audioread(srcImpresp);
    
    % resample
    inpResampled = resample(inp, imprespSampleRate, inpSampleRate);
    inpResampledSampleRate = imprespSampleRate;

    % convolve
    if shouldConv
        outp = conv(inpResampled, impresp);
    else
        % set size to the output of time domain convolution to avoid circular property of ifft
        % set size to be a power of 2
        outpLength = length(inpResampled) + length(impresp) - 1;
        nfft = 2^nextpow2(outpLength);

        % convolution in frequency domain
        inpResampledFFT = fft(inpResampled, nfft);
        imprespFFT = fft(impresp, nfft);
        outp = ifft(inpResampledFFT .* imprespFFT);

        % cut the padding
        outp = outp(1:outpLength);
    end
    outpSampleRate = imprespSampleRate;

    % rescale
    outp = rescale(outp, min(inpResampled), max(inpResampled), min(outp), max(outp));

    % write
    audiowrite(srcOutp, outp, outpSampleRate);
end

function data = rescale(data, prevMin, prevMax, currentMin, currentMax)
    if -prevMin > prevMax
        scale = -prevMin / -currentMin;
    else
        scale = prevMax / currentMax;
    end
    data = data .* scale;
end

function playAudio(audio, sampleRate)
    player = audioplayer(audio, sampleRate);
    player.playblocking();
end

function addEffectToMic(srcImpresp, chunkSize, micFs)
    %DELETE THIS
%     fs = 8000;  % to large sample rate?
%     buffSize = 4024; % to small/large? fs=8000=>impresp=12605

    % read
    [impresp, imprespSampleRate] = audioread(srcImpresp);
    impresp = resample(impresp, micFs, imprespSampleRate);
    imprespSampleRate = micFs;

    % set size to the output of time domain convolution to avoid circular property of ifft
    % set size to be a power of 2
    nfft = 2^nextpow2(chunkSize + length(impresp) - 1);

    % cache FFT of impresp
    imprespFFT = fft(impresp, nfft);

    % outside visibility of outp, overlap
    overlap = zeros(0,1);

    % read from microphone
    adr = audioDeviceReader(micFs, chunkSize, 'NumChannels', 1);
    adr.Device = "Default";
    %setup(adr); %  Call setup to reduce the computational load of initialization in an audio stream loop.
    adw = audioDeviceWriter(micFs, 'SupportVariableSizeInput', true, 'BufferSize', chunkSize);
    while true
        chunk = adr();
        [chunkOutp, overlap] = addEffectToChunk(chunk, imprespFFT, nfft, chunkSize, overlap);
        adw(chunkOutp);
    end
end