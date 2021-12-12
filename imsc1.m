[outp,outpSampleRate] = addeffect("pavarotti_original.wav", "impresp_mono.wav");
audiowrite('pavarotti_conv3.wav', outp, outpSampleRate);

%a = audiodevinfo;
%a.output

%addEffectToMic("impresp_mono.wav");

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
        %resample(inbuf,speakerFs,micFs);
        
        % windowing
        %inbuf = inbuf .* wind;
        %inbuf = (inbuf' * diag(wind))';

        % convolve
        outbuf = conv(impresp, inbuf);

        % windowing
        %outbuf = outbuf .* hamming(length(outbuf));

        adw(inbuf); % order of elements ?
    end
    %release(deviceReader)
end

function [outp, outpSampleRate] = addeffect(srcAudio, srcImpresp)
    % read
    [inp, inpSampleRate] = audioread(srcAudio);
    [impresp, imprespSampleRate] = audioread(srcImpresp);

    % check range
    inpMax = max(inp);
    
    % resample
    inpResampled = resample(inp, imprespSampleRate, inpSampleRate);
    inpResampledSampleRate = imprespSampleRate;

    % debug
    %playAudio(inpResampled, inpResampledSampleRate);
    %playAudio(impresp, imprespSampleRate);

    % convolve
    outp = conv(inpResampled, impresp);
    outpSampleRate = imprespSampleRate;

    % check range
    outpMax = max(outp);

    % rescale
    outp = outp .* (inpMax / outpMax);

    disp("Conv done");
end

function playAudio(audio, sampleRate)
    player = audioplayer(audio, sampleRate);
    player.playblocking();
end