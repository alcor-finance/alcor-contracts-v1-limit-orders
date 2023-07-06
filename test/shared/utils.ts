import { ethers } from 'hardhat'
import { BigNumber } from 'ethers'

export function delay(seconds: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, seconds * 1000)
  })
}

// important: 1.0001^tick (not 1.0001^(-tick))
export const tickToPrice = (tick: number): BigNumber => {
  return ethers.utils.parseEther(Math.pow(1.0001, tick).toString())
}