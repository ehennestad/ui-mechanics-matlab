function rgb = wavelengthToRgb(wavelength)
%wavelengthToRgb Approximate the colour of visible light of a wavelength
%
%   rgb = uim.utility.wavelengthToRgb(wavelength) returns a 1-by-3 RGB
%   triplet (values from 0 to 1) for a wavelength in nanometres.
%   Wavelengths are clamped to 380-780 nm, and the brightness falls off
%   towards both ends of that range (below 420 nm and above 700 nm).
%   wavelength must be a positive, finite scalar.
%
%   Example:
%       uim.utility.wavelengthToRgb(545)   % [0.5, 1, 0]

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
