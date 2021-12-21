clear all;

%addEffect("pavarotti_original.wav", "impresp_mono.wav", "pavarotti_conv.wav", false);
%simulateRealTime("pavarotti_original.wav", "impresp_mono.wav", "pavarotti_conv.wav", 2048);
%addEffectToMic("impresp_mono.wav", 2048, 44100);

function simulateRealTime(srcInp, srcImpresp, srcOutp, chunkSize)
    % read
    [inp, inpSampleRate] = getAudioMono(srcInp);
    [impresp, imprespSampleRate] = getAudioMono(srcImpresp);
    
    % resample
    inpResampled = resample(inp, imprespSampleRate, inpSampleRate);
    inpResampledSampleRate = imprespSampleRate;

    % set size to the output of time domain convolution to avoid circular property of dft
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

    % write
    audiowrite(srcOutp, outp, outpSampleRate);
end

function value = energy(data)
    value = sum(data .* data);
end

% only use energy for caching reasons in caller side
function data = rescaleByEnergy(data, energyCurrent, energyOriginal)
    if energyOriginal ~= 0
        ratio = energyCurrent / energyOriginal;
        data = data .* (1/sqrt(ratio));
    end
end

function data = rescaleChunk(data, chunkSize)
    data = data ./ sqrt(chunkSize);
end

% overlap-add algorithm
function [chunkOutp, overlap] = addEffectToChunk(chunk, imprespFFT, nfft, chunkSize, overlap)
    if length(overlap) == 0
        % overlap should be at least chunkSize + 1
        % being multiple of chunkSize makes it easier to work with
        overlap = zeros(chunkSize * 2, 1);
    end

    % convolution in frequency domain
    chunkConved = ifft(fft(chunk, nfft) .* imprespFFT);

    % rescale for chunkOutp, overlapCurrent
    chunkConved = rescaleChunk(chunkConved, chunkSize);

    % set output based on convolution and overlap (from previous convolutions)
    chunkOutp = chunkConved(1:chunkSize) + overlap(1:chunkSize);

    % remove used overlap part
    overlap = overlap(chunkSize+1:end);

    % calculate new overlap based on unused part of chunkConved
    overlapCurrent = chunkConved(chunkSize+1:end);
    %overlapCurrent = rescaleChunk(overlapCurrent, chunkSize);
    % |overlapCurrent| > |overlap|
    overlap = paddingZero(overlap, length(overlapCurrent)) + overlapCurrent; 

    % make it to a multiple of chunkSize for easier use
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

function addEffect(srcInp, srcImpresp, srcOutp, shouldConv)
    % read
    [inp, inpSampleRate] = getAudioMono(srcInp);
    [impresp, imprespSampleRate] = getAudioMono(srcImpresp);
    
    % resample
    inpResampled = resample(inp, imprespSampleRate, inpSampleRate);
    inpResampledSampleRate = imprespSampleRate;

    % convolve
    if shouldConv
        outp = conv(inpResampled, impresp);
    else
        % set size to the output of time domain convolution to avoid circular property of dft
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
    % it's important to use inp not inpResampled as inpResampled's values can also go out of range
    outp = rescaleByEnergy(outp, energy(outp), energy(inp));

    % write
    audiowrite(srcOutp, outp, outpSampleRate);
end

function playAudio(audio, sampleRate)
    player = audioplayer(audio, sampleRate);
    player.playblocking();
end

function [data, dataSampleRate] = getAudioMono(src)
    [data, dataSampleRate] = audioread(src);
    data = data(:,1);
end

function addEffectToMic(srcImpresp, chunkSize, micFs)
    % read
    [impresp, imprespSampleRate] = getAudioMono(srcImpresp);

    % set size to the output of time domain convolution to avoid circular property of dft
    % set size to be a power of 2
    nfft = 2^nextpow2(chunkSize + length(impresp) - 1);

    % cache FFT of impresp
    imprespFFT = fft(impresp, nfft);

    % outside visibility of outp, overlap
    overlap = zeros(0,1);

    % read from microphone
    adr = audioDeviceReader('SamplesPerFrame', chunkSize, 'NumChannels', 1, "Device", "USB2.0 Camera: Audio (hw:0,0)", "SampleRate", 32000);
    setup(adr); %  Call setup to reduce the computational load of initialization in an audio stream loop.
    adw = audioDeviceWriter('SampleRate',adr.SampleRate, 'SupportVariableSizeInput', true, 'BufferSize', chunkSize);
    
    %resample
    impresp = resample(impresp, adr.SampleRate, imprespSampleRate);
    imprespSampleRate = adr.SampleRate;

    while true
        chunk = adr();
        [chunkOutp, overlap] = addEffectToChunk(chunk, imprespFFT, nfft, chunkSize, overlap);
        adw(chunkOutp);
    end
end