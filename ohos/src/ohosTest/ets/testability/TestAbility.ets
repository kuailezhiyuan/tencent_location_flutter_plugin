import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { Hypium } from '@ohos/hypium'
import testsuite from '../test/List.test'

/** 执行插件内部 Codec 测试的 Hypium Ability。 */
export default class TestAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    const abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator()
    const testArguments = abilityDelegatorRegistry.getArguments()
    Hypium.hypiumTest(abilityDelegator, testArguments, testsuite)
  }
}
