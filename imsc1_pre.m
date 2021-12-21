clear all;

[inp, inpSampleRate] = getAudioMono("pavarotti_original.wav");

% plot
% create x axis based on inpSampleRate
duration = length(inp) / inpSampleRate;
delta = duration / length(inp);
plot(delta:delta:duration, inp);
xlabel('seconds');
ylabel('amplitude');

% playback
playAudio(inp, inpSampleRate);

function playAudio(audio, sampleRate)
    player = audioplayer(audio, sampleRate);
    player.playblocking();
end

function [data, dataSampleRate] = getAudioMono(src)
    [data, dataSampleRate] = audioread(src);
    data = data(:,1);
end
