export default function PendingApprovalPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-brand-900 to-brand-700 flex items-center justify-center p-4">
      <div className="card max-w-md w-full p-8 text-center">
        <div className="text-5xl mb-4">⏳</div>
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Account Pending Approval</h1>
        <p className="text-gray-500 text-sm mb-6">
          Your account has been submitted successfully. A Director will review and approve your account.
          You&apos;ll receive your Member ID and login credentials once approved.
        </p>
        <p className="text-xs text-gray-400">
          Please check back later or contact your sponsor/director for updates.
        </p>
        <a href="/login" className="btn-primary mt-6 inline-flex">Back to Login</a>
      </div>
    </div>
  )
}
