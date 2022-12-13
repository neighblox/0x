// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract NBKycContract is Ownable{
    mapping (address => bool) public approvedAdminAccess;
    mapping (address => bool) public approvedCustomerAccess;
    mapping (address => bool) public approvedBusinessAccess;
    mapping (address => bool) public approvedAdvAccess;

    function setKycForAdmin(address _addr) public onlyOwner {
        approvedAdminAccess[_addr] = true;
    }

    function setKycForCustomer(address _addr) public onlyOwner {
        approvedCustomerAccess[_addr] = true;
    }

    function setKycForBusiness(address _addr) public onlyOwner {
        approvedBusinessAccess[_addr] = true;
    }

    function setKycForAdvertiser(address _addr) public onlyOwner {
        approvedAdvAccess[_addr] = true;
    }

    function revokedForAdmin(address _addr) public onlyOwner {
        approvedAdminAccess[_addr] = false;
    }

    function revokedForCustomer(address _addr) public onlyOwner {
        approvedCustomerAccess[_addr] = false;
    }

    function revokedForBusiness(address _addr) public onlyOwner {
        approvedBusinessAccess[_addr] = false;
    }

    function revokedForAdvertiser(address _addr) public onlyOwner {
        approvedAdvAccess[_addr] = false;
    }

    function kycStatusForAdmin(address _addr) public view returns(bool) {
        return approvedAdminAccess[_addr];
    }

    function kycStatusForCustomer(address _addr) public view returns(bool) {
        return approvedCustomerAccess[_addr];
    }

    function kycStatusForBusiness(address _addr) public view returns(bool) {
        return approvedBusinessAccess[_addr];
    }

    function kycStatusForAdvertiser(address _addr) public view returns(bool) {
        return approvedAdvAccess[_addr];
    }
}
