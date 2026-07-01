'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Trophy, Clock, Calendar } from 'lucide-react'
import { getStatusLabel } from '@/lib/types'

type Period = 'week' | 'month' | 'all'
type Board = 'consistent' | 'punctual'

interface LeaderEntry {
  id: string
  full_name: string
  member_id: string | null
  status: string
  color_group_id: string | null
  total_days: number
  signed_in_days: number
  punctual_days: number
  hex_color?: string
}

export default function Leaderboard({ colorGroups }: { colorGroups: { id: string; hex_color: string; name: string }[] }) {
  const [period, setPeriod] = useState<Period>('month')
  const [board, setBoard] = useState<Board>('consistent')
  const [data, setData] = useState<LeaderEntry[]>([])
  const [loading, setLoading] = useState(true)

  const colorMap = Object.fromEntries(colorGroups.map(g => [g.id, g]))

  useEffect(() => {
    load()
  }, [period, board])

  async function load() {
    setLoading(true)
    const supabase = createClient()

    let query = supabase
      .from('attendance_leaderboard')
      .select('*')
      .order(board === 'consistent' ? 'signed_in_days' : 'punctual_days', { ascending: false })
      .limit(20)

    const { data } = await query
    setData(data ?? [])
    setLoading(false)
  }

  const medals = ['🥇', '🥈', '🥉']

  return (
    <div className="card p-5">
      <div className="flex items-center gap-2 mb-4">
        <Trophy className="text-yellow-500" size={20} />
        <h2 className="section-title">Leaderboard</h2>
      </div>

      <div className="flex gap-2 mb-4 flex-wrap">
        {/* Board type */}
        <div className="flex gap-1 bg-gray-100 p-1 rounded-lg">
          <button onClick={() => setBoard('consistent')} className={`px-3 py-1.5 rounded-md text-xs font-semibold transition-all ${board === 'consistent' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500'}`}>
            <Calendar size={12} className="inline mr-1" />Most Consistent
          </button>
          <button onClick={() => setBoard('punctual')} className={`px-3 py-1.5 rounded-md text-xs font-semibold transition-all ${board === 'punctual' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500'}`}>
            <Clock size={12} className="inline mr-1" />Most Punctual
          </button>
        </div>
        {/* Period */}
        <div className="flex gap-1 bg-gray-100 p-1 rounded-lg">
          {(['week', 'month', 'all'] as Period[]).map(p => (
            <button key={p} onClick={() => setPeriod(p)} className={`px-3 py-1.5 rounded-md text-xs font-semibold capitalize transition-all ${period === p ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500'}`}>
              {p === 'all' ? 'All Time' : `This ${p.charAt(0).toUpperCase() + p.slice(1)}`}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="text-center py-8 text-gray-400 text-sm">Loading…</div>
      ) : data.length === 0 ? (
        <div className="text-center py-8 text-gray-400 text-sm">No data yet</div>
      ) : (
        <div className="space-y-2">
          {data.map((entry, i) => {
            const cg = colorMap[entry.color_group_id ?? '']
            const score = board === 'consistent' ? entry.signed_in_days : entry.punctual_days
            const maxScore = board === 'consistent' ? data[0].signed_in_days : data[0].punctual_days
            return (
              <div key={entry.id} className="flex items-center gap-3 p-3 rounded-xl bg-gray-50">
                <div className="w-8 text-center font-bold text-lg">
                  {i < 3 ? medals[i] : <span className="text-gray-400 text-sm">#{i + 1}</span>}
                </div>
                <div className="w-8 h-8 rounded-full flex items-center justify-center font-bold text-white text-sm flex-shrink-0"
                  style={{ backgroundColor: cg?.hex_color ?? '#6366f1' }}>
                  {entry.full_name.charAt(0)}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-semibold text-gray-900 text-sm truncate">{entry.full_name}</div>
                  <div className="text-xs text-gray-400">{entry.member_id} · {getStatusLabel(entry.status as any)}</div>
                </div>
                <div className="text-right">
                  <div className="font-bold text-gray-900">{score}</div>
                  <div className="text-xs text-gray-400">{board === 'consistent' ? 'days' : 'on time'}</div>
                </div>
                <div className="w-20 bg-gray-200 rounded-full h-1.5">
                  <div className="h-1.5 rounded-full bg-indigo-500" style={{ width: `${maxScore > 0 ? (score / maxScore) * 100 : 0}%` }} />
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
