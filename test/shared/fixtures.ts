import { Decimal } from 'decimal.js'
import { BigNumber, Wallet } from 'ethers'
import { ethers } from 'hardhat'


import { TokenERC20 } from '../../typechain/TokenERC20'
import { AlcorFactory } from '../../typechain/AlcorFactory'
import { MockAlcorPoolCallOption } from '../../typechain/MockAlcorPoolCallOption'


Decimal.config({ toExpNeg: -500, toExpPos: 500 })

export const Tokens = [
    ['tUSDC', 'tUSDC', BigNumber.from(2).pow(150).toString()],
    ['tWETH', 'tWETH', BigNumber.from(2).pow(150).toString()],
]

export async function deployTokensFixture() {
    const tokenFactory = await ethers.getContractFactory('TokenERC20')
    const tokenA = (await tokenFactory.deploy(Tokens[0][0], Tokens[0][1], Tokens[0][2])) as TokenERC20
    const tokenB = (await tokenFactory.deploy(Tokens[1][0], Tokens[1][1], Tokens[1][2])) as TokenERC20
    await tokenA.deployTransaction.wait()
    await tokenB.deployTransaction.wait()

    const [token0, token1] = [tokenA, tokenB].sort((tokenA, tokenB) =>
        tokenA.address.toLowerCase() < tokenB.address.toLowerCase() ? -1 : 1
    )

    return [token0.address, token1.address]
}

export const loadTokensFixture = async (token0Address: string, token1Address: string, signer: Wallet) => {
    let tokenFactory = await ethers.getContractFactory('TokenERC20', signer)
    let token0 = tokenFactory.attach(token0Address) as TokenERC20
    let token1 = tokenFactory.attach(token1Address) as TokenERC20
    return [token0, token1]
}

export const FactoryFixture = async () => {
    const factoryFactory = await ethers.getContractFactory('AlcorFactory')
    return (await factoryFactory.deploy()) as AlcorFactory
}

export const loadAlcorFactory = async (alcor_factory_address: string, signer: Wallet) => {
    const MockAlcorPool = await ethers.getContractFactory('AlcorFactory', signer)
    let alcor_factory = await MockAlcorPool.attach(alcor_factory_address) as AlcorFactory
    return alcor_factory
}

export const createAlcorPoolCallOption = async (
    factory: AlcorFactory,
    token0: TokenERC20,
    token1: TokenERC20,
    optionExpiration: string | BigNumber,
    optionStrikePrice: string | BigNumber
) => {
    const create = await factory.createPoolCallOption(token0.address, token1.address, optionExpiration, optionStrikePrice)
    const receipt = await create.wait()

    let alcor_pool_address = receipt.events?.[0].args?.pool as string
    return alcor_pool_address
}

export const loadAlcorPoolCallOptionContract = async (alcor_pool_address: string, signer: Wallet) => {
    const MockAlcorPool = await ethers.getContractFactory('MockAlcorPoolCallOption', signer)
    let mock_alcor_pool_call_option = await MockAlcorPool.attach(alcor_pool_address) as MockAlcorPoolCallOption
    return mock_alcor_pool_call_option
}