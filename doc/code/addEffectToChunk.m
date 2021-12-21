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