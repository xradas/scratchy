package os.scratchy.patches

import os.scratchy.engine.TargetIdentity
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ExactTextReplacementPatchTest {
    private val patch = ExactTextReplacementPatch(
        id = "fixture.replace-welcome-label.v1",
        description = "Replaces one approved fixture label.",
        targetPackage = "os.scratchy.fixture",
        supportedVersionCode = 1,
        resourcePath = "res/values/strings.xml",
        expectedText = "Welcome fixture",
        replacementText = "Patched fixture",
    )

    @Test fun `supports only its exact target version`() {
        assertTrue(patch.supports(TargetIdentity("os.scratchy.fixture", "1.0", 1)))
        assertFalse(patch.supports(TargetIdentity("os.scratchy.fixture", "1.1", 2)))
    }

    @Test fun `rejects resource without exactly one expected value`() {
        val input = TextResource("res/values/strings.xml", "Welcome fixture; Welcome fixture")
        assertTrue(patch.validatePreconditions(input) != null)
        assertTrue(patch.apply(input).isFailure)
    }

    @Test fun `applies and validates an exact replacement`() {
        val input = TextResource("res/values/strings.xml", "Welcome fixture")
        val output = patch.apply(input).getOrThrow()
        assertTrue(output.content == "Patched fixture")
        assertNull(patch.validateResult(output))
    }
}
