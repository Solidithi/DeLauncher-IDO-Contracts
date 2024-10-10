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

    function getPrice(
        string memory _base,
        string memory _quote
    ) external view returns (uint256, uint256, uint256) {
        IStdReference.ReferenceData memory data = ref.getReferenceData(
            _base,
            _quote
        );
        return (data.rate, data.lastUpdatedBase, data.lastUpdatedQuote);
    }

    function getPrices(
        string[] memory _bases,
        string[] memory _quotes
    ) external view returns (uint256[] memory) {
        IStdReference.ReferenceData[] memory data = ref.getReferenceDataBulk(
            _bases,
            _quotes
        );

        uint256[] memory prices = new uint256[](_bases.length);
        for (uint256 i = 0; i < _bases.length; i++) {
            prices[i] = data[i].rate;
        }

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
