// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import "../interfaces/IDoubleOracle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DoubleOracle is Ownable {
    uint256 public price;
    IStdReference public ref;

    constructor(IStdReference _ref) Ownable(msg.sender) {
        ref = _ref;
    }

    function getPrice() external view returns (uint256) {
        IStdReference.ReferenceData memory data = ref.getReferenceData(
            "BTC",
            "USD"
        );
        return data.rate;
    }

    function getMultiPrices() external view returns (uint256[] memory) {
        string[] memory baseSymbols = new string[](2);
        baseSymbols[0] = "WBTC";
        baseSymbols[1] = "DOT";

        string[] memory quoteSymbols = new string[](2);
        quoteSymbols[0] = "USD";
        quoteSymbols[1] = "USDT";
        IStdReference.ReferenceData[] memory data = ref.getReferenceDataBulk(
            baseSymbols,
            quoteSymbols
        );

        uint256[] memory prices = new uint256[](2);
        prices[0] = data[0].rate;
        prices[1] = data[1].rate;

        return prices;
    }

    function savePrice(
        string memory base,
        string memory quote
    ) external onlyOwner {
        IStdReference.ReferenceData memory data = ref.getReferenceData(
            base,
            quote
        );
        price = data.rate;
    }
}
