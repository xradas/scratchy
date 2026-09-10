package os.scratchy.engine

/** Android-independent contracts for a fail-closed APK transformation pipeline. */
data class TargetIdentity(
    val packageName: String,
    val versionName: String,
    val versionCode: Long,
)

sealed interface InspectionResult {
    data class Identified(val target: TargetIdentity) : InspectionResult
    data class Rejected(val diagnostic: Diagnostic) : InspectionResult
}

data class Diagnostic(val code: String, val message: String)

/** A target must be explicitly listed before any transformation can be considered. */
class TargetPolicy(private val acceptedPackages: Set<String>) {
    fun evaluate(identity: TargetIdentity): InspectionResult =
        if (identity.packageName in acceptedPackages) {
            InspectionResult.Identified(identity)
        } else {
            InspectionResult.Rejected(
                Diagnostic(
                    code = "unsupported-package",
                    message = "${identity.packageName} is not an approved Scratchy target.",
                ),
            )
        }
}

interface TargetInspector<Input> {
    fun inspect(input: Input): InspectionResult
}

interface PatchDefinition<Input> {
    val id: String
    val description: String
    fun supports(target: TargetIdentity): Boolean
    fun validatePreconditions(input: Input): Diagnostic?
    fun apply(input: Input): Result<Input>
    fun validateResult(output: Input): Diagnostic?
}
