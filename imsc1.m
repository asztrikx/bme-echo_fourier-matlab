addEffect("pavarotti_original.wav", "impresp_mono.wav", "pavarotti_conv.wav", true);
%simulateRealTime("pavarotti_original.wav", "impresp_mono.wav", "pavarotti_conv.wav");

function simulateRealTime(srcInp, srcImpresp, srcOutp)
    % read
    [inp, inpSampleRate] = audioread(srcInp);
    [impresp, imprespSampleRate] = audioread(srcImpresp);
    
    % resample
    inpResampled = resample(inp, imprespSampleRate, inpSampleRate);
    inpResampledSampleRate = imprespSampleRate;

    % length of block size
    chunkSize = 1024;

    % length of FFT output
    % https://www.mathworks.com/help/signal/ref/fftfilt.html
    nfft = 2^nextpow2(chunkSize + length(impresp) - 1);

    % cache FFT of impresp
    imprespFFT = fft(impresp, nfft);

    outp = zeros(0,1);
    outpSampleRate = imprespSampleRate;

    % overlap-add algorithm

    % overlap should be at least chunkSize + 1
    % being multiple of chunkSize makes it easier to work with
    overlap = zeros(chunkSize * 2, 1);
    % padding to chunkSize
    inpResampled = paddingZeroMultiply(inpResampled, chunkSize);
    for idx = 1:chunkSize:length(inpResampled)
        from = idx;
        to = min(idx + chunkSize - 1, length(inpResampled));
        
        chunkInp = inpResampled(from:to);

        x = ifft(fft(chunkInp, nfft) .* imprespFFT);
        chunkOutp = x(1:chunkSize) + overlap(1:chunkSize);
        overlap = overlap(chunkSize+1:end);
        xRemainderSize = length(x(chunkSize+1:end));
        overlap = paddingZero(overlap, xRemainderSize) + x(chunkSize+1:end);
        overlap = paddingZeroMultiply(overlap, chunkSize);

        outp = [outp; chunkOutp];
    end

    % append remaining overlap
    outp = [outp; overlap];

    % rescale
    outp = rescale(outp, min(inpResampled), max(inpResampled), min(outp), max(outp));

    % write
    audiowrite(srcOutp, outp, outpSampleRate);
end

function addEffectToMic(srcImpresp)
    %DELETE THIS
    fs = 8000;  % to large sample rate?
    buffSize = 4024; % to small/large? fs=8000=>impresp=12605

    % read
    [impresp, imprespSampleRate] = audioread(srcImpresp);
    impresp = resample(impresp, fs, imprespSampleRate);
    imprespSampleRate = fs;
    %playAudio(impresp, imprespSampleRate);
    soundsc(impresp, imprespSampleRate);

    % delete this
    impresp = ones(length(impresp), 1);

    micFs = 44100;
    speakerFs = 44100;
    adr = audioDeviceReader(micFs, buffSize, 'NumChannels', 1);
    % valid values
    % ?: "Default"
    % TV: "HD-Audio Generic: ALC255 Analog (hw:1,0)"
    % Nothing: "pipewire"
    % TV: "pulse"
    adr.Device = "Default";
    %setup(adr); %  Call setup to reduce the computational load of initialization in an audio stream loop.
    adw = audioDeviceWriter(speakerFs, 'SupportVariableSizeInput', true, 'BufferSize', buffSize);
    %inbuf = zeros(buffSize,1);
    wind = blackman(buffSize);
    while true
        inbuf = adr(); % order of elements?
        adw(addEffectToChunk(inbuf)); % order of elements ?
    end
    %release(deviceReader)
end

% chunk and impresp should be at same samplerate
function chunk = addEffectToChunk(chunk, imprespFFT, chunkSize)
    
end

function data = paddingZeroMultiply(data, n)
    data = [data; zeros(n - mod(length(data), n), 1)];
end

function data = paddingZero(data, size)
    if length(data) > size 
        disp("wrong param");
    end
    data = [data; zeros(size - length(data), 1)];
end

function addEffect(srcInp, srcImpresp, srcOutp, shouldConv)
    % read
    [inp, inpSampleRate] = audioread(srcInp);
    [impresp, imprespSampleRate] = audioread(srcImpresp);
    
    % resample
    inpResampled = resample(inp, imprespSampleRate, inpSampleRate);
    inpResampledSampleRate = imprespSampleRate;

    % idk
    inpResampled = [inpResampled; zeros(length(impresp), 1)];
    impresp = [impresp; zeros(length(inpResampled), 1)];

    % convolve
    if shouldConv
        % conv 6min vs 1-2 seconds
        outp = conv(inpResampled, impresp);
    else
        inpResampledFFT = fft(inpResampled, length(inpResampled));
        imprespFFT = fft(impresp, length(inpResampled));
        outp = ifft(inpResampledFFT .* imprespFFT);
    end
    outpSampleRate = imprespSampleRate;

    % rescale
    outp = rescale(outp, min(inpResampled), max(inpResampled), min(outp), max(outp));

    % write
    audiowrite(srcOutp, outp, outpSampleRate);
end

function data = rescale(data, prevMin, prevMax, currentMin, currentMax)
    % handles min being positive, max being negative?
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