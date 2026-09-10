package os.scratchy.engine

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ContractsTest {
    @Test fun `unknown target has an explicit rejection diagnostic`() {
        val result: InspectionResult = InspectionResult.Rejected(Diagnostic("unknown-target", "Unsupported package"))
        assertTrue(result is InspectionResult.Rejected)
        assertFalse((result as InspectionResult.Rejected).diagnostic.message.isBlank())
    }

    @Test fun `policy rejects a package that was not explicitly approved`() {
        val policy = TargetPolicy(setOf("com.example.approved"))
        val result = policy.evaluate(TargetIdentity("com.example.other", "1.0", 1))
        assertTrue(result is InspectionResult.Rejected)
        assertTrue((result as InspectionResult.Rejected).diagnostic.code == "unsupported-package")
    }

    @Test fun `policy identifies an explicitly approved package`() {
        val policy = TargetPolicy(setOf("com.example.approved"))
        val result = policy.evaluate(TargetIdentity("com.example.approved", "1.0", 1))
        assertTrue(result is InspectionResult.Identified)
    }
}
