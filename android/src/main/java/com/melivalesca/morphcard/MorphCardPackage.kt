package com.melivalesca.morphcard

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

class MorphCardPackage : BaseReactPackage() {
  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return when (name) {
      MorphCardModule.NAME -> MorphCardModule(reactContext)
      else -> null
    }
  }

  override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
    return ReactModuleInfoProvider {
      mapOf(
        MorphCardModule.NAME to
          ReactModuleInfo(
            MorphCardModule.NAME,
            MorphCardModule.NAME,
            false,
            false,
            false,
            true,
          )
      )
    }
  }

  override fun createViewManagers(
    reactContext: ReactApplicationContext
  ): List<ViewManager<*, *>> {
    return listOf(
      MorphCardSourceManager(),
      MorphCardTargetManager(),
    )
  }
}
