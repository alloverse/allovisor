local allomath = {}

function allomath.sign(number)
    return number > 0 and 1 or (number == 0 and 0 or -1)
end

return allomath