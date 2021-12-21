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