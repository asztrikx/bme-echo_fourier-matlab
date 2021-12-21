function data = rescaleChunk(data, chunkSize)
    data = data ./ sqrt(chunkSize);
end