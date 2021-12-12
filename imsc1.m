%addEffect("pavarotti_original.wav", "impresp_mono.wav", "pavarotti_conv.wav");
simulateRealTime("pavarotti_original.wav", "impresp_mono.wav", "pavarotti_conv.wav");

function simulateRealTime(srcInp, srcImpresp, srcOutp)
    % read
    [inp, inpSampleRate] = audioread(srcInp);
    [impresp, imprespSampleRate] = audioread(srcImpresp);
    
    % resample
    inpResampled = resample(inp, imprespSampleRate, inpSampleRate);
    inpResampledSampleRate = imprespSampleRate;

    % cache FFT of impresp
    imprespFFT = fft(impresp);

    % convolve chunk by chunk
    %outp = zeros(1, length(inpResampled) + length(impresp) - 1);
    outp = zeros(0,1);
    outpSampleRate = imprespSampleRate;

    chunkSize = 10240;
    for idx = 1:chunkSize:length(inpResampled)
        from = idx;
        to = min(idx + chunkSize - 1, length(inpResampled));

        %outp(from:to) = addEffectToChunk(inpResampled(from:to), impresp);
        outp = [outp; addEffectToChunk(inpResampled(from:to), imprespFFT, chunkSize)];
    end

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
    % windowing
    %inbuf = inbuf .* wind;
    %inbuf = (inbuf' * diag(wind))';
    
    %bandwidth of windows function
    %look at pdfs
    %correct position in array when multiplying
    chunkFFT = fft(chunk);
    wind = hamming(chunkSize);
    %windFFT = fft(wind);
    chunkFFT = padd(chunkFFT, chunkSize);
    chunkFFT = chunkFFT .* imprespFFT(1:chunkSize); % .* windFFT;
    chunk = real(ifft(chunk));
    chunk = padd(chunk, chunkSize);
    chunk = chunk .* wind;
    
    % windowing
    %outbuf = outbuf .* hamming(length(outbuf));
end

function addEffect(srcInp, srcImpresp, srcOutp)
    % read
    [inp, inpSampleRate] = audioread(srcInp);
    [impresp, imprespSampleRate] = audioread(srcImpresp);
    
    % resample
    inpResampled = resample(inp, imprespSampleRate, inpSampleRate);
    inpResampledSampleRate = imprespSampleRate;

    % convolve
    outp = conv(inpResampled, impresp);
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

function data = padd(data, size)
    data = [data; zeros(size - length(data), 1)];
end

function playAudio(audio, sampleRate)
    player = audioplayer(audio, sampleRate);
    player.playblocking();
end