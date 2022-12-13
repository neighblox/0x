// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract KycContract is Ownable{
    mapping (address => bool) public approvedForGenesis;
    mapping (address => bool) public approvedForSecondStage;
    mapping (address => bool) public approvedForThirdStage;
    mapping (address => bool) public approvedForFourthStage;

    function setKycForGenesis(address _addr) public onlyOwner {
        approvedForGenesis[_addr] = true;
    }

    function setKycForSecondStage(address _addr) public onlyOwner {
        approvedForSecondStage[_addr] = true;
    }

    function setKycForThirdStage(address _addr) public onlyOwner {
        approvedForThirdStage[_addr] = true;
    }

    function setKycForFourthStage(address _addr) public onlyOwner {
        approvedForFourthStage[_addr] = true;
    }

    function revokedForGenesis(address _addr) public onlyOwner {
        approvedForGenesis[_addr] = false;
    }

    function revokedForSecondStage(address _addr) public onlyOwner {
        approvedForSecondStage[_addr] = false;
    }

    function revokedForThirdStage(address _addr) public onlyOwner {
        approvedForThirdStage[_addr] = false;
    }

    function revokedForFourthStage(address _addr) public onlyOwner {
        approvedForFourthStage[_addr] = false;
    }

    function kycStatusForGenesis(address _addr) public view returns(bool) {
        return approvedForGenesis[_addr];
    }

    function kycStatusForSecondStage(address _addr) public view returns(bool) {
        return approvedForSecondStage[_addr];
    }

    function kycStatusForThirdStage(address _addr) public view returns(bool) {
        return approvedForThirdStage[_addr];
    }

    function kycStatusForFourthStage(address _addr) public view returns(bool) {
        return approvedForFourthStage[_addr];
    }
}
