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