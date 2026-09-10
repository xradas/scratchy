package os.scratchy.patches

import os.scratchy.engine.PatchDefinition

/** Registry boundary for reviewed, benign, version-aware patch definitions. */
interface PatchCatalog<Input> {
    fun available(): List<PatchDefinition<Input>>
}
