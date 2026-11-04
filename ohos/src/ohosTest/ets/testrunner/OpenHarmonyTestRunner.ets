import { Want } from '@kit.AbilityKit'
import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'

/** 启动插件测试模块的 TestAbility。 */
export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {}

  onRun(): void {
    const abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator()
    const testArguments = abilityDelegatorRegistry.getArguments()
    const moduleName = testArguments.parameters['-m']
    if (moduleName === undefined) {
      abilityDelegator.finishTest('Missing test module name.', -1, () => {})
      return
    }

    const want: Want = {
      bundleName: testArguments.bundleName,
      abilityName: 'TestAbility',
      moduleName,
    }
    abilityDelegator.startAbility(want, () => {})
  }
}
