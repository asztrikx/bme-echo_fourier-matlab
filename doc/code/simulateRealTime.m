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