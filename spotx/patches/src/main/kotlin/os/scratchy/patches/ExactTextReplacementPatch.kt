package os.scratchy.patches

import os.scratchy.engine.Diagnostic
import os.scratchy.engine.PatchDefinition
import os.scratchy.engine.TargetIdentity

/** A non-proprietary proof-of-concept patch for a single known text-resource value. */
data class TextResource(val path: String, val content: String)

class ExactTextReplacementPatch(
    override val id: String,
    override val description: String,
    private val targetPackage: String,
    private val supportedVersionCode: Long,
    private val resourcePath: String,
    private val expectedText: String,
    private val replacementText: String,
) : PatchDefinition<TextResource> {
    override fun supports(target: TargetIdentity): Boolean =
        target.packageName == targetPackage && target.versionCode == supportedVersionCode

    override fun validatePreconditions(input: TextResource): Diagnostic? = when {
        input.path != resourcePath -> Diagnostic("unexpected-resource", "Expected resource $resourcePath was not selected.")
        input.content.countOccurrences(expectedText) != 1 -> Diagnostic("unexpected-content", "Expected text must appear exactly once before patching.")
        else -> null
    }

    override fun apply(input: TextResource): Result<TextResource> {
        val precondition = validatePreconditions(input)
        if (precondition != null) return Result.failure(IllegalStateException(precondition.message))
        return Result.success(input.copy(content = input.content.replace(expectedText, replacementText)))
    }

    override fun validateResult(output: TextResource): Diagnostic? = when {
        output.path != resourcePath -> Diagnostic("unexpected-resource", "Patched resource path changed unexpectedly.")
        output.content.countOccurrences(expectedText) != 0 -> Diagnostic("original-content-remains", "Original text remains after patching.")
        output.content.countOccurrences(replacementText) != 1 -> Diagnostic("replacement-invalid", "Replacement text must appear exactly once after patching.")
        else -> null
    }
}

private fun String.countOccurrences(value: String): Int =
    if (value.isEmpty()) 0 else split(value).size - 1
