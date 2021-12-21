function data = paddingZeroMultiple(data, n)
    data = [data; zeros(n - mod(length(data), n), 1)];
end