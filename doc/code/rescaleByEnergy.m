% only use energy for caching reasons in caller side
function data = rescaleByEnergy(data, energyCurrent, energyOriginal)
    if energyOriginal ~= 0
        ratio = energyCurrent / energyOriginal;
        data = data .* (1/sqrt(ratio));
    end
end