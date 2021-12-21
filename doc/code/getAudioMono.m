function [data, dataSampleRate] = getAudioMono(src)
    [data, dataSampleRate] = audioread(src);
    data = data(:,1);
end