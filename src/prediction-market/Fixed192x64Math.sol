pragma solidity ^0.8.20;
// pragma solidity >=0.4.24 ^0.5.1;

/// @title Fixed192x64Math library - Allows calculation of logarithmic and exponential functions
/// @author Alan Lu - <alan.lu@gnosis.pm>
/// @author Stefan George - <stefan@gnosis.pm>
library Fixed192x64Math {
    enum EstimationMode {
        LowerBound,
        UpperBound,
        Midpoint
    }

    /*
     *  Constants
     */
    // This is equal to 1 in our calculations
    uint256 public constant ONE = 0x10000000000000000;
    uint256 public constant LN2 = 0xb17217f7d1cf79ac;
    uint256 public constant LOG2_E = 0x171547652b82fe177;

    /*
     *  Public functions
     */
    /// @dev Returns natural exponential function value of given x
    /// @param x x
    /// @return e**x
    function exp(int256 x) public pure returns (uint256) {
        // revert if x is > MAX_POWER, where
        // MAX_POWER = int(mp.floor(mp.log(mpf(2**256 - 1) / ONE) * ONE))
        require(x <= 2454971259878909886679);
        // return 0 if exp(x) is tiny, using
        // MIN_POWER = int(mp.floor(mp.log(mpf(1) / ONE) * ONE))
        if (x <= -818323753292969962227) return 0;

        // Transform so that e^x -> 2^x
        (uint256 lower, uint256 upper) = pow2Bounds((x * int256(ONE)) / int256(LN2));
        return (upper - lower) / 2 + lower;
    }

    /// @dev Returns estimate of 2**x given x
    /// @param x exponent in fixed point
    /// @param estimationMode whether to return a lower bound, upper bound, or a midpoint
    /// @return estimate of 2**x in fixed point
    function pow2(int256 x, EstimationMode estimationMode) public pure returns (uint256) {
        (uint256 lower, uint256 upper) = pow2Bounds(x);
        if (estimationMode == EstimationMode.LowerBound) {
            return lower;
        }
        if (estimationMode == EstimationMode.UpperBound) {
            return upper;
        }
        if (estimationMode == EstimationMode.Midpoint) {
            return (upper - lower) / 2 + lower;
        }
        revert();
    }

    /// @dev Returns bounds for value of 2**x given x
    /// @param x exponent in fixed point
    /// @return lower upper {
    ///   "lower": "lower bound of 2**x in fixed point",
    ///   "upper": "upper bound of 2**x in fixed point"
    /// }
    function pow2Bounds(int256 x) public pure returns (uint256 lower, uint256 upper) {
        // revert if x is > MAX_POWER, where
        // MAX_POWER = int(mp.floor(mp.log(mpf(2**256 - 1) / ONE, 2) * ONE))
        require(x <= 3541774862152233910271);
        // return 0 if exp(x) is tiny, using
        // MIN_POWER = int(mp.floor(mp.log(mpf(1) / ONE, 2) * ONE))
        if (x < -1180591620717411303424) return (0, 1);

        // 2^x = 2^(floor(x)) * 2^(x-floor(x))
        //       ^^^^^^^^^^^^^^ is a bit shift of ceil(x)
        // so Taylor expand on z = x-floor(x), z in [0, 1)
        int256 shift;
        int256 z;
        if (x >= 0) {
            shift = x / int256(ONE);
            z = x % int256(ONE);
        } else {
            shift = (x + 1) / int256(ONE) - 1;
            z = x - (int256(ONE) * shift);
        }
        assert(z >= 0);
        // 2^x = 1 + (ln 2) x + (ln 2)^2/2! x^2 + ...
        //
        // Can generate the z coefficients using mpmath and the following lines
        // >>> from mpmath import mp
        // >>> mp.dps = 100
        // >>> coeffs = [mp.log(2)**i / mp.factorial(i) for i in range(1, 21)]
        // >>> shifts = [64 - int(mp.log(c, 2)) for c in coeffs]
        // >>> print('\n'.join(hex(int(c * (1 << s))) + ', ' + str(s) for c, s in zip(coeffs, shifts)))
        int256 result = int256(ONE) << 64;
        int256 zpow = z;
        result += 0xb17217f7d1cf79ab * zpow;
        zpow = (zpow * z) / int256(ONE);
        result += (0xf5fdeffc162c7543 * zpow) >> (66 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xe35846b82505fc59 * zpow) >> (68 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0x9d955b7dd273b94e * zpow) >> (70 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xaec3ff3c53398883 * zpow) >> (73 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xa184897c363c3b7a * zpow) >> (76 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xffe5fe2c45863435 * zpow) >> (80 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xb160111d2e411fec * zpow) >> (83 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xda929e9caf3e1ed2 * zpow) >> (87 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xf267a8ac5c764fb7 * zpow) >> (91 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xf465639a8dd92607 * zpow) >> (95 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xe1deb287e14c2f15 * zpow) >> (99 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xc0b0c98b3687cb14 * zpow) >> (103 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0x98a4b26ac3c54b9f * zpow) >> (107 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xe1b7421d82010f33 * zpow) >> (112 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0x9c744d73cfc59c91 * zpow) >> (116 - 64);
        zpow = (zpow * z) / int256(ONE);
        result += (0xcc2225a0e12d3eab * zpow) >> (121 - 64);
        zpow = (zpow * z) / int256(ONE);
        zpow = (0xfb8bb5eda1b4aeb9 * zpow) >> (126 - 64);
        result += zpow;
        zpow = int256(8 * ONE);

        shift -= 64;
        if (shift >= 0) {
            uint256 ushift = uint256(shift);
            if (result >> (256 - ushift) == 0) {
                lower = uint256(result) << ushift;
                zpow <<= ushift; // todo: is this safe?
                if (lower + uint256(zpow) >= lower) upper = lower + uint256(zpow);
                else upper = 2 ** 256 - 1;
                return (lower, upper);
            } else {
                return (2 ** 256 - 1, 2 ** 256 - 1);
            }
        }
        // We'll only get here if shfit is negative
        uint256 nshift = uint256(-shift);
        // zpow = (zpow >> (-shift)) + 1;
        // lower = uint(result) >> (-shift);
        zpow = (zpow >> (nshift)) + 1;
        lower = uint256(result) >> (nshift);
        upper = lower + uint256(zpow);
        return (lower, upper);
    }

    /// @dev Returns natural logarithm value of given x
    /// @param x x
    /// @return ln(x)
    function ln(uint256 x) public pure returns (int256) {
        (int256 lower, int256 upper) = log2Bounds(x);
        return (((upper - lower) / 2 + lower) * int256(ONE)) / int256(LOG2_E);
    }

    /// @dev Returns estimate of binaryLog(x) given x
    /// @param x logarithm argument in fixed point
    /// @param estimationMode whether to return a lower bound, upper bound, or a midpoint
    /// @return estimate of binaryLog(x) in fixed point
    function binaryLog(uint256 x, EstimationMode estimationMode) public pure returns (int256) {
        (int256 lower, int256 upper) = log2Bounds(x);
        if (estimationMode == EstimationMode.LowerBound) {
            return lower;
        }
        if (estimationMode == EstimationMode.UpperBound) {
            return upper;
        }
        if (estimationMode == EstimationMode.Midpoint) {
            return (upper - lower) / 2 + lower;
        }
        revert();
    }

    /// @dev Returns bounds for value of binaryLog(x) given x
    /// @param x logarithm argument in fixed point
    /// @return lower upper {
    ///   "lower": "lower bound of binaryLog(x) in fixed point",
    ///   "upper": "upper bound of binaryLog(x) in fixed point"
    /// }
    function log2Bounds(uint256 x) public pure returns (int256 lower, int256 upper) {
        require(x > 0);
        // compute ⌊log₂x⌋
        lower = floorLog2(x);

        uint256 y;
        if (lower < 0) y = x << uint256(-lower);
        else y = x >> uint256(lower);

        lower *= int256(ONE);

        // y = x * 2^(-⌊log₂x⌋)
        // so 1 <= y < 2
        // and log₂x = ⌊log₂x⌋ + log₂y
        for (int256 m = 1; m <= 64; m++) {
            if (y == ONE) {
                break;
            }
            y = (y * y) / ONE;
            if (y >= 2 * ONE) {
                uint256 um = uint256(m);
                lower += int256(ONE >> um);
                y /= 2;
            }
        }

        return (lower, lower + 4);
    }

    /// @dev Returns base 2 logarithm value of given x
    /// @param x x
    /// @return lo logarithmic value
    function floorLog2(uint256 x) public pure returns (int256 lo) {
        lo = -64;
        int256 hi = 193;
        // I use a shift here instead of / 2 because it floors instead of rounding towards 0
        int256 mid = (hi + lo) >> 1;
        while ((lo + 1) < hi) {
            if ((mid < 0 && x << uint256(-mid) < ONE) || (mid >= 0 && x >> uint256(mid) < ONE)) hi = mid;
            else lo = mid;
            mid = (hi + lo) >> 1;
        }
    }

    /// @dev Returns maximum of an array
    /// @param nums Numbers to look through
    /// @return maxNum Maximum number
    function max(int256[] memory nums) public pure returns (int256 maxNum) {
        require(nums.length > 0);
        maxNum = -2 ** 255;
        for (uint256 i = 0; i < nums.length; i++) {
            if (nums[i] > maxNum) maxNum = nums[i];
        }
    }
}
