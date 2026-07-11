function rgb = wavelengthToRgb(wavelength)
%WAVELENGTHTORGB Approximate a visible-light wavelength as an RGB triplet.

    arguments
        wavelength (1,1) double {mustBeFinite, mustBePositive}
    end

    wavelength = min(max(wavelength, 380), 780);
    if wavelength < 440
        rgb = [-(wavelength-440)/(440-380), 0, 1];
    elseif wavelength < 490
        rgb = [0, (wavelength-440)/(490-440), 1];
    elseif wavelength < 510
        rgb = [0, 1, -(wavelength-510)/(510-490)];
    elseif wavelength < 580
        rgb = [(wavelength-510)/(580-510), 1, 0];
    elseif wavelength < 645
        rgb = [1, -(wavelength-645)/(645-580), 0];
    else
        rgb = [1, 0, 0];
    end

    if wavelength < 420
        intensity = 0.3 + 0.7*(wavelength-380)/(420-380);
    elseif wavelength <= 700
        intensity = 1;
    else
        intensity = 0.3 + 0.7*(780-wavelength)/(780-700);
    end
    rgb = max(0, min(1, rgb * intensity));
end
