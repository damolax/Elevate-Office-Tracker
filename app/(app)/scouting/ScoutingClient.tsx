'use client'

import { useState, useRef } from 'react'
import { format, parseISO } from 'date-fns'
import * as XLSX from 'xlsx'
import { createClient } from '@/lib/supabase/client'
import type { Profile, ScoutingRecord } from '@/lib/types'
import { Upload, Download, Search, Trophy } from 'lucide-react'

const REQUIRED_FIELDS = ['Business', 'Rating', 'Reviews', 'Band', 'Profile link']
const OPTIONAL_FIELDS = ['Industry', 'Email', 'Match Score', 'Issues Found', 'Status', 'Message Sent', 'Their Reply', 'Source']

type GroupStat = { name: string; hex_color: string; total: number }

export default function ScoutingClient({
  profile, isAdmin, myRecords, myCount, allRecords, groupStats,
}: {
  profile: Profile
  isAdmin: boolean
  myRecords: ScoutingRecord[]
  myCount: number
  allRecords: (ScoutingRecord & { profiles: { full_name: string; member_id: string; color_groups: { name: string; hex_color: string } } })[]
  groupStats: GroupStat[]
}) {
  const [tab, setTab] = useState<'my' | 'upload' | 'all' | 'groups'>('my')
  const [uploading, setUploading] = useState(false)
  const [uploadMsg, setUploadMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [uploadPreview, setUploadPreview] = useState<Record<string, string>[] | null>(null)
  const [search, setSearch] = useState('')
  const fileRef = useRef<HTMLInputElement>(null)

  const today = format(new Date(), 'yyyy-MM-dd')
  const myToday = myRecords.filter(r => r.scouted_at.startsWith(today)).length
  const myThisWeek = myRecords.filter(r => {
    const d = parseISO(r.scouted_at)
    const diff = (new Date().getTime() - d.getTime()) / (1000 * 60 * 60 * 24)
    return diff <= 7
  }).length

  function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (ev) => {
      try {
        const wb = XLSX.read(ev.target?.result, { type: 'binary' })
        const ws = wb.Sheets[wb.SheetNames[0]]
        const data = XLSX.utils.sheet_to_json<Record<string, string>>(ws, { defval: '' })

        // Validate fields
        const headers = Object.keys(data[0] ?? {})
        const missing = REQUIRED_FIELDS.filter(f => !headers.includes(f))
        if (missing.length > 0) {
          setUploadMsg({ type: 'error', text: `Invalid file. Missing required columns: ${missing.join(', ')}` })
          setUploadPreview(null)
          return
        }
        setUploadPreview(data)
        setUploadMsg({ type: 'success', text: `✓ ${data.length} records ready to upload` })
      } catch {
        setUploadMsg({ type: 'error', text: 'Could not read file. Please upload a valid Excel (.xlsx) file.' })
      }
    }
    reader.readAsBinaryString(file)
  }

  async function confirmUpload() {
    if (!uploadPreview) return
    setUploading(true)
    setUploadMsg(null)
    const supabase = createClient()
    const batchId = crypto.randomUUID()

    const records = uploadPreview.map(row => ({
      user_id: profile.id,
      business_name: String(row['Business'] ?? ''),
      rating: String(row['Rating'] ?? ''),
      reviews: String(row['Reviews'] ?? ''),
      band: String(row['Band'] ?? ''),
      profile_link: String(row['Profile link'] ?? ''),
      industry: String(row['Industry'] ?? '') || null,
      email: String(row['Email'] ?? '') || null,
      match_score: String(row['Match Score'] ?? '') || null,
      issues_found: String(row['Issues Found'] ?? '') || null,
      status: String(row['Status'] ?? 'Pending') || 'Pending',
      message_sent: String(row['Message Sent'] ?? '') || null,
      their_reply: String(row['Their Reply'] ?? '') || null,
      source: String(row['Source'] ?? 'Scout App') || 'Scout App',
      scouted_at: new Date().toISOString(),
      upload_batch_id: batchId,
    })).filter(r => r.business_name)

    // Upsert (skip duplicates based on user_id + profile_link)
    let inserted = 0
    let skipped = 0

    for (let i = 0; i < records.length; i += 100) {
      const batch = records.slice(i, i + 100)
      const { data, error } = await supabase.from('scouting_records')
        .upsert(batch, { onConflict: 'user_id,profile_link', ignoreDuplicates: true })
        .select('id')
      if (error) {
        setUploadMsg({ type: 'error', text: error.message })
        setUploading(false)
        return
      }
      inserted += data?.length ?? 0
      skipped += batch.length - (data?.length ?? 0)
    }

    setUploadMsg({ type: 'success', text: `✓ Uploaded ${inserted} new records. ${skipped} duplicates skipped.` })
    setUploadPreview(null)
    if (fileRef.current) fileRef.current.value = ''
    setTimeout(() => window.location.reload(), 1500)
    setUploading(false)
  }

  function downloadMyRecords() {
    const data = myRecords.map(r => ({
      'Business': r.business_name,
      'Rating': r.rating,
      'Reviews': r.reviews,
      'Band': r.band,
      'Profile link': r.profile_link,
      'Industry': r.industry,
      'Email': r.email,
      'Match Score': r.match_score,
      'Issues Found': r.issues_found,
      'Status': r.status,
      'Message Sent': r.message_sent,
      'Their Reply': r.their_reply,
      'Source': r.source,
      'Scouted At': format(parseISO(r.scouted_at), 'yyyy-MM-dd HH:mm'),
    }))
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(data), 'Scouting Records')
    XLSX.writeFile(wb, `scouting_${profile.member_id}_${today}.xlsx`)
  }

  const filtered = myRecords.filter(r =>
    !search ||
    r.business_name.toLowerCase().includes(search.toLowerCase()) ||
    (r.email ?? '').toLowerCase().includes(search.toLowerCase()) ||
    (r.status ?? '').toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {[
          { id: 'my', label: `My Records (${myCount})` },
          { id: 'upload', label: 'Upload Today\'s List' },
          ...(isAdmin ? [{ id: 'all', label: 'All Scouting' }, { id: 'groups', label: 'Group Rankings' }] : []),
        ].map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id as any)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* My Records */}
      {tab === 'my' && (
        <div className="space-y-4">
          <div className="grid grid-cols-3 gap-4">
            {[
              { label: 'Scouted Today', value: myToday },
              { label: 'Last 7 Days', value: myThisWeek },
              { label: 'All Time', value: myCount },
            ].map(s => (
              <div key={s.label} className="card p-4 text-center">
                <div className="text-2xl font-extrabold text-gray-900">{s.value.toLocaleString()}</div>
                <div className="text-xs text-gray-400 mt-0.5">{s.label}</div>
              </div>
            ))}
          </div>

          <div className="flex gap-3">
            <div className="relative flex-1 max-w-sm">
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input className="input pl-8 py-2" placeholder="Search business, email…" value={search} onChange={e => setSearch(e.target.value)} />
            </div>
            <button onClick={downloadMyRecords} className="btn-secondary">
              <Download size={15} /> Download All
            </button>
          </div>

          <div className="card overflow-x-auto">
            {filtered.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No scouting records yet. Upload your first list!</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="border-b border-gray-100">
                  <tr>
                    <th className="table-th">Business</th>
                    <th className="table-th">Rating</th>
                    <th className="table-th">Email</th>
                    <th className="table-th">Status</th>
                    <th className="table-th">Scouted</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map(r => (
                    <tr key={r.id} className="table-row">
                      <td className="table-td max-w-xs">
                        <div className="font-medium truncate">{r.business_name}</div>
                        {r.profile_link && (
                          <a href={r.profile_link} target="_blank" rel="noreferrer" className="text-xs text-brand-500 hover:underline">View profile</a>
                        )}
                      </td>
                      <td className="table-td">{r.rating ?? '—'} <span className="text-gray-400 text-xs">({r.reviews} reviews)</span></td>
                      <td className="table-td text-xs text-gray-400">{r.email ?? '—'}</td>
                      <td className="table-td">
                        <span className={`badge ${r.status === 'Contacted' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'}`}>
                          {r.status}
                        </span>
                      </td>
                      <td className="table-td text-xs text-gray-400">{format(parseISO(r.scouted_at), 'MMM d, HH:mm')}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}

      {/* Upload */}
      {tab === 'upload' && (
        <div className="space-y-4 max-w-xl">
          <div className="card p-6">
            <h2 className="section-title mb-2">Upload Today&apos;s Scouting List</h2>
            <p className="text-sm text-gray-500 mb-4">
              Upload an Excel file exported from the Scout App. Required columns:
              <strong> Business, Rating, Reviews, Band, Profile link</strong>.
              Duplicate entries (same profile link) are automatically skipped.
            </p>

            <div
              className="border-2 border-dashed border-gray-200 rounded-xl p-8 text-center cursor-pointer hover:border-brand-300 transition-colors"
              onClick={() => fileRef.current?.click()}
            >
              <Upload size={28} className="mx-auto mb-2 text-gray-400" />
              <div className="text-sm font-medium text-gray-600">Click to upload Excel file</div>
              <div className="text-xs text-gray-400 mt-1">.xlsx files only</div>
            </div>
            <input ref={fileRef} type="file" accept=".xlsx,.xls" className="hidden" onChange={handleFileSelect} />

            {uploadMsg && (
              <div className={`mt-3 px-4 py-3 rounded-lg text-sm border ${uploadMsg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
                {uploadMsg.text}
              </div>
            )}

            {uploadPreview && uploadPreview.length > 0 && (
              <div className="mt-4 space-y-3">
                <div className="text-sm font-medium text-gray-700">Preview (first 5 rows):</div>
                <div className="overflow-x-auto">
                  <table className="w-full text-xs border border-gray-100 rounded-lg overflow-hidden">
                    <thead className="bg-gray-50">
                      <tr>{REQUIRED_FIELDS.map(f => <th key={f} className="px-2 py-1.5 text-left font-medium text-gray-500">{f}</th>)}</tr>
                    </thead>
                    <tbody>
                      {uploadPreview.slice(0, 5).map((row, i) => (
                        <tr key={i} className="border-t border-gray-100">
                          {REQUIRED_FIELDS.map(f => <td key={f} className="px-2 py-1.5 text-gray-600 max-w-32 truncate">{row[f] ?? '—'}</td>)}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <button onClick={confirmUpload} disabled={uploading} className="btn-primary w-full py-3">
                  {uploading ? 'Uploading…' : `Upload ${uploadPreview.length} Records`}
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* All scouting (admin) */}
      {tab === 'all' && isAdmin && (
        <div className="card overflow-x-auto">
          <div className="p-4 border-b border-gray-100 flex items-center justify-between">
            <h2 className="section-title">All Scouting Records</h2>
            <span className="text-sm text-gray-400">{allRecords.length} records</span>
          </div>
          <table className="w-full text-sm">
            <thead className="border-b border-gray-100">
              <tr>
                <th className="table-th">Scouter</th>
                <th className="table-th">Business</th>
                <th className="table-th">Group</th>
                <th className="table-th">Status</th>
                <th className="table-th">Date</th>
              </tr>
            </thead>
            <tbody>
              {allRecords.map(r => (
                <tr key={r.id} className="table-row">
                  <td className="table-td">
                    <div className="flex items-center gap-2">
                      <div className="w-5 h-5 rounded-full" style={{ backgroundColor: (r as any).profiles?.color_groups?.hex_color ?? '#ccc' }} />
                      <div>
                        <div className="font-medium">{(r as any).profiles?.full_name}</div>
                        <div className="text-xs text-gray-400">{(r as any).profiles?.member_id}</div>
                      </div>
                    </div>
                  </td>
                  <td className="table-td max-w-xs truncate">{r.business_name}</td>
                  <td className="table-td text-sm">{(r as any).profiles?.color_groups?.name ?? '—'}</td>
                  <td className="table-td">
                    <span className={`badge ${r.status === 'Contacted' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'}`}>{r.status}</span>
                  </td>
                  <td className="table-td text-xs text-gray-400">{format(parseISO(r.scouted_at), 'MMM d, HH:mm')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Group rankings */}
      {tab === 'groups' && isAdmin && (
        <div className="card p-5">
          <h2 className="section-title mb-4">
            <Trophy size={18} className="inline mr-2 text-yellow-500" />
            Group Scouting Rankings
          </h2>
          <div className="space-y-3">
            {groupStats.map((g, i) => (
              <div key={g.name} className="flex items-center gap-4 p-3 rounded-xl bg-gray-50">
                <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold text-sm ${i === 0 ? 'bg-yellow-100 text-yellow-700' : 'bg-gray-100 text-gray-500'}`}>
                  {i + 1}
                </div>
                <div className="w-4 h-4 rounded-full flex-shrink-0" style={{ backgroundColor: g.hex_color }} />
                <div className="font-semibold flex-1">{g.name}</div>
                <div className="font-bold text-gray-900">{g.total.toLocaleString()} businesses</div>
                <div className="w-32 bg-gray-200 rounded-full h-2">
                  <div
                    className="h-2 rounded-full"
                    style={{ backgroundColor: g.hex_color, width: `${(g.total / (groupStats[0]?.total || 1)) * 100}%` }}
                  />
                </div>
              </div>
            ))}
            {groupStats.length === 0 && (
              <p className="text-sm text-gray-400 text-center py-8">No scouting data yet</p>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
