import { Decimal } from 'decimal.js'
import { BigNumber, Wallet } from 'ethers'
import { ethers } from 'hardhat'
import { expect } from '../shared/expect'

import { TokenERC20 } from '../../typechain/TokenERC20'
import { AlcorFactory } from '../../typechain/AlcorFactory'
import { MockAlcorPoolCallOption } from '../../typechain/MockAlcorPoolCallOption'

import { delay, tickToPrice } from '../shared/utils'
import { formatTokenAmount } from '../shared/format'

import { mumbaiFactoryAddr, mumbaiUSDC2, mumbaiWETH2 } from '../constants'

import {
    Tokens, deployTokensFixture,
    loadTokensFixture, FactoryFixture,
    createAlcorPoolCallOption,
    loadAlcorPoolCallOptionContract,
    loadAlcorFactory
} from '../shared/fixtures'


Decimal.config({ toExpNeg: -500, toExpPos: 500 })

const AlcorPoolsParams = [{
    isCallOption: true,
    optionExpiration: "1695978000",
    // optionStrikePrice: ethers.utils.parseEther("2200")
}]


describe('AlcorFactory: get user info multiple pools', () => {
    let account1: Wallet, account2: Wallet, account3: Wallet
    let token0Addr: string, token1Addr: string
    let factory: AlcorFactory
    // let mock_alcor_pool_call_option_address: string
    // const { optionExpiration, optionStrikePrice } = AlcorPoolsParams[0];

    token0Addr = mumbaiUSDC2
    token1Addr = mumbaiWETH2
    // let loadFixture: ReturnType<typeof createFixtureLoader>
    before("load wallets", async () => {
        [account1, account2, account3] = await (ethers as any).getSigners()
        console.log(account1.address, account2.address, account3.address)
    })

    before("load factory", async () => {
        let deployer: Wallet = account1
        factory = await loadAlcorFactory(mumbaiFactoryAddr, deployer)
        console.log("factory:", factory.address)
    })

    before("load tokens", async () => {
        let deployer: Wallet = account1
        let [token0, token1] = await loadTokensFixture(token0Addr, token1Addr, deployer)
        console.log("token0:", token0.address)
        console.log("token1:", token1.address)
    })

    let poolsAddresses: string[] = []
    it("get addresses multiple pools", async () => {
        let signer: Wallet = account1
        poolsAddresses = await factory.getAddressesForPairAndExpiration(
            token0Addr,
            token1Addr,
            AlcorPoolsParams[0].optionExpiration,
            AlcorPoolsParams[0].isCallOption)

        console.log(poolsAddresses)

        for (let i = 0; i < poolsAddresses.length; i++) {
            let mock_alcor_pool_call_option = await loadAlcorPoolCallOptionContract(poolsAddresses[i], signer)
            let userInfo = await mock_alcor_pool_call_option.usersInfo(signer.address)
            console.log(i, userInfo)
        }
    })

})