import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import { MockTimeAlcorPool } from '../../typechain/MockTimeAlcorPool'
import { TestERC20 } from '../../typechain/TestERC20'
import { AlcorFactory } from '../../typechain/AlcorFactory'
import { TestAlcorCallee } from '../../typechain/TestAlcorCallee'
import { TestAlcorRouter } from '../../typechain/TestAlcorRouter'
import { MockTimeAlcorPoolDeployer } from '../../typechain/MockTimeAlcorPoolDeployer'

import { Fixture } from 'ethereum-waffle'

interface FactoryFixture {
  factory: AlcorFactory
}

async function factoryFixture(): Promise<FactoryFixture> {
  const factoryFactory = await ethers.getContractFactory('AlcorFactory')
  const factory = (await factoryFactory.deploy()) as AlcorFactory
  return { factory }
}

interface TokensFixture {
  token0: TestERC20
  token1: TestERC20
  token2: TestERC20
}

async function tokensFixture(): Promise<TokensFixture> {
  const tokenFactory = await ethers.getContractFactory('TestERC20')
  const tokenA = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as TestERC20
  const tokenB = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as TestERC20
  const tokenC = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as TestERC20

  const [token0, token1, token2] = [tokenA, tokenB, tokenC].sort((tokenA, tokenB) =>
    tokenA.address.toLowerCase() < tokenB.address.toLowerCase() ? -1 : 1
  )

  return { token0, token1, token2 }
}

type TokensAndFactoryFixture = FactoryFixture & TokensFixture

interface PoolFixture extends TokensAndFactoryFixture {
  swapTargetCallee: TestAlcorCallee
  swapTargetRouter: TestAlcorRouter
  createPool(
    fee: number,
    tickSpacing: number,
    firstToken?: TestERC20,
    secondToken?: TestERC20
  ): Promise<MockTimeAlcorPool>
}

// Monday, October 5, 2020 9:00:00 AM GMT-05:00
export const TEST_POOL_START_TIME = 1601906400

export const poolFixture: Fixture<PoolFixture> = async function (): Promise<PoolFixture> {
  const { factory } = await factoryFixture()
  const { token0, token1, token2 } = await tokensFixture()

  const MockTimeAlcorPoolDeployerFactory = await ethers.getContractFactory('MockTimeAlcorPoolDeployer')
  const MockTimeAlcorPool = await ethers.getContractFactory('MockTimeAlcorPool')

  const calleeContractFactory = await ethers.getContractFactory('TestAlcorCallee')
  const routerContractFactory = await ethers.getContractFactory('TestAlcorRouter')

  const swapTargetCallee = (await calleeContractFactory.deploy()) as TestAlcorCallee
  const swapTargetRouter = (await routerContractFactory.deploy()) as TestAlcorRouter

  return {
    token0,
    token1,
    token2,
    factory,
    swapTargetCallee,
    swapTargetRouter,
    createPool: async (fee, tickSpacing, firstToken = token0, secondToken = token1) => {
      const mockTimePoolDeployer = (await MockTimeAlcorPoolDeployerFactory.deploy()) as MockTimeAlcorPoolDeployer
      const tx = await mockTimePoolDeployer.deploy(
        factory.address,
        firstToken.address,
        secondToken.address,
        fee,
        tickSpacing
      )

      const receipt = await tx.wait()
      const poolAddress = receipt.events?.[0].args?.pool as string
      return MockTimeAlcorPool.attach(poolAddress) as MockTimeAlcorPool
    },
  }
}
