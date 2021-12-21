function data = paddingZero(data, size)
    if length(data) > size 
        disp("wrong param");
    end
    data = [data; zeros(size - length(data), 1)];
end