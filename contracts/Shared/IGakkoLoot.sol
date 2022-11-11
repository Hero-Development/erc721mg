
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IGakkoLoot{
  function handlePull( address from, address to, uint16 parentTokenId ) external;
}
