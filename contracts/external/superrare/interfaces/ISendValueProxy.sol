pragma solidity 0.7.3;

interface ISendValueProxy {
    function sendValue(address payable _to) external payable;
}