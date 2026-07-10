'use client'

import { useRouter } from 'next/navigation'
import { Eye, X } from 'lucide-react'

export default function ViewAsBanner({ name }: { name: string }) {
  const router = useRouter()

  async function exit() {
    await fetch('/api/admin/view-as', { method: 'DELETE' })
    router.push('/people')
    router.refresh()
  }

  return (
    <div className="bg-amber-500 text-white px-4 py-2 flex items-center justify-between gap-3 text-sm font-medium sticky top-0 z-50">
      <div className="flex items-center gap-2">
        <Eye size={16} />
        <span>Viewing as <strong>{name}</strong> — this is what they see, not you.</span>
      </div>
      <button onClick={exit} className="flex items-center gap-1 bg-white/20 hover:bg-white/30 rounded-md px-2.5 py-1">
        <X size={14} /> Exit
      </button>
    </div>
  )
}
