'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import type { ColorGroup, UserStatus } from '@/lib/types'
import { format } from 'date-fns'

const STATUSES: { value: UserStatus; label: string }[] = [
  { value: 'member', label: 'Member' },
  { value: 'distributor', label: 'Distributor' },
  { value: 'manager', label: 'Manager' },
  { value: 'senior_manager', label: 'Senior Manager' },
  { value: 'executive_manager', label: 'Executive Manager' },
  { value: 'director', label: 'Director' },
]

export default function SignupPage() {
  const router = useRouter()
  const [step, setStep] = useState(1)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [colorGroups, setColorGroups] = useState<ColorGroup[]>([])

  const [form, setForm] = useState({
    full_name: '',
    email: '',
    phone: '',
    password: '',
    confirm_password: '',
    status: 'member' as UserStatus,
    color_group_id: '',
    no_color_yet: false,
    sponsor_in_office: null as boolean | null,
    sponsor_id: '',
    sponsor_search: '',
    is_office_already: true,
  })

  const [sponsorOptions, setSponsorOptions] = useState<{ id: string; full_name: string; member_id: string }[]>([])

  useEffect(() => {
    const supabase = createClient()
    supabase.from('color_groups').select('id, name, hex_color').order('name').then(({ data }) => {
      if (data) setColorGroups(data as ColorGroup[])
    })
  }, [])

  async function searchSponsor(query: string) {
    if (query.length < 2) { setSponsorOptions([]); return }
    const supabase = createClient()
    const { data } = await supabase
      .from('profiles')
      .select('id, full_name, member_id')
      .eq('approved', true)
      .not('member_id', 'is', null)
      .or(`full_name.ilike.%${query}%,member_id.ilike.%${query}%`)
      .limit(8)
    setSponsorOptions(data ?? [])
  }

  function validateStep(): string | null {
    if (step === 1) {
      if (!form.full_name.trim()) return 'Full name is required'
      if (!form.email.trim()) return 'Email is required'
      if (!form.password) return 'Password is required'
      if (form.password.length < 8) return 'Password must be at least 8 characters'
      if (form.password !== form.confirm_password) return 'Passwords do not match'
    }
    if (step === 3) {
      if (form.sponsor_in_office === null) return 'Please answer the sponsor question'
      if (form.sponsor_in_office && !form.sponsor_id) return 'Please search and select your sponsor from the list'
    }
    return null
  }

  function handleNext(e: React.FormEvent) {
    e.preventDefault()
    const err = validateStep()
    if (err) { setError(err); return }
    setError('')
    setStep(s => s + 1)
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const err = validateStep()
    if (err) { setError(err); return }
    setError('')
    setLoading(true)

    try {
      const supabase = createClient()

      const { data: authData, error: authError } = await supabase.auth.signUp({
        email: form.email,
        password: form.password,
      })

      if (authError || !authData.user) throw new Error(authError?.message ?? 'Signup failed')

      // Use API route (service role) to bypass RLS on profile insert
      const res = await fetch('/api/signup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: authData.user.id,
          full_name: form.full_name.trim(),
          email: form.email.toLowerCase().trim(),
          phone: form.phone.trim() || null,
          status: form.status,
          color_group_id: form.no_color_yet ? null : (form.color_group_id || null),
          sponsor_id: form.sponsor_in_office ? (form.sponsor_id || null) : null,
          is_office_already: form.is_office_already,
          is_new_member: !form.is_office_already,
          new_member_month: !form.is_office_already ? format(new Date(), 'yyyy-MM') : null,
          week_number: 1,
        }),
      })

      const result = await res.json()
      if (!res.ok) throw new Error(result.error ?? 'Failed to create profile')

      router.push('/pending-approval')
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Something went wrong')
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-brand-900 to-brand-700 flex items-center justify-center p-4">
      <div className="w-full max-w-lg">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-white/20 rounded-2xl mb-4">
            <span className="text-white font-black text-2xl">E</span>
          </div>
          <h1 className="text-white text-2xl font-bold">Create Your Account</h1>
          <p className="text-white/60 text-sm mt-1">Step {step} of 3</p>
        </div>

        <div className="flex gap-2 mb-6">
          {[1,2,3].map(s => (
            <div key={s} className={`flex-1 h-1.5 rounded-full transition-colors ${s <= step ? 'bg-white' : 'bg-white/30'}`} />
          ))}
        </div>

        <div className="card p-8">
          <form onSubmit={step < 3 ? handleNext : handleSubmit}>

            {/* Step 1: Personal Info */}
            {step === 1 && (
              <div className="space-y-4">
                <h2 className="section-title mb-4">Personal Information</h2>
                <div>
                  <label className="label">Full Name *</label>
                  <input className="input" value={form.full_name} onChange={e => setForm(f => ({ ...f, full_name: e.target.value }))} placeholder="Your full name" />
                </div>
                <div>
                  <label className="label">Email Address *</label>
                  <input className="input" type="email" value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} placeholder="you@example.com" />
                </div>
                <div>
                  <label className="label">Phone Number</label>
                  <input className="input" value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))} placeholder="+234 xxx xxx xxxx" />
                </div>
                <div>
                  <label className="label">Password *</label>
                  <input className="input" type="password" value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))} placeholder="Min. 8 characters" />
                </div>
                <div>
                  <label className="label">Confirm Password *</label>
                  <input className="input" type="password" value={form.confirm_password} onChange={e => setForm(f => ({ ...f, confirm_password: e.target.value }))} placeholder="Repeat password" />
                </div>
              </div>
            )}

            {/* Step 2: Role & Color */}
            {step === 2 && (
              <div className="space-y-4">
                <h2 className="section-title mb-4">Role & Group</h2>

                <div>
                  <label className="label">Your Status *</label>
                  <select className="input" value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value as UserStatus }))}>
                    {STATUSES.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
                  </select>
                </div>

                <div>
                  <label className="label">Color Group</label>
                  <div className="flex items-start gap-3 mb-3">
                    <input type="checkbox" id="no-color" checked={form.no_color_yet} onChange={e => setForm(f => ({ ...f, no_color_yet: e.target.checked, color_group_id: '' }))} className="mt-1" />
                    <label htmlFor="no-color" className="text-sm text-gray-600 cursor-pointer">I don&apos;t have a color group yet</label>
                  </div>
                  {!form.no_color_yet && (
                    <div className="grid grid-cols-2 gap-2">
                      {colorGroups.map(g => (
                        <button key={g.id} type="button" onClick={() => setForm(f => ({ ...f, color_group_id: g.id }))}
                          className={`flex items-center gap-2 p-2.5 rounded-lg border-2 transition-all text-sm font-medium ${form.color_group_id === g.id ? 'border-brand-500 bg-brand-50' : 'border-gray-200 hover:border-gray-300'}`}>
                          <div className="w-4 h-4 rounded-full flex-shrink-0" style={{ backgroundColor: g.hex_color }} />
                          {g.name}
                        </button>
                      ))}
                    </div>
                  )}
                </div>

                <div>
                  <label className="label">Office Attendance</label>
                  <div className="space-y-2">
                    {[
                      { value: true, label: 'I have been coming to the office already' },
                      { value: false, label: 'I just started coming to the office this month' },
                    ].map(opt => (
                      <label key={String(opt.value)} className="flex items-center gap-3 p-3 rounded-lg border border-gray-200 cursor-pointer hover:bg-gray-50">
                        <input type="radio" name="office" checked={form.is_office_already === opt.value} onChange={() => setForm(f => ({ ...f, is_office_already: opt.value }))} />
                        <span className="text-sm">{opt.label}</span>
                      </label>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* Step 3: Sponsor */}
            {step === 3 && (
              <div className="space-y-5">
                <h2 className="section-title mb-1">Sponsor</h2>

                {/* Key question */}
                <div>
                  <label className="label">Is your sponsor a member of Elevate Office or Elicitors Team?</label>
                  <div className="space-y-2 mt-1">
                    {[
                      { value: true, label: 'Yes — they have an account here' },
                      { value: false, label: 'No — they are not in the system' },
                    ].map(opt => (
                      <label key={String(opt.value)} className={`flex items-center gap-3 p-3 rounded-lg border-2 cursor-pointer transition-all ${form.sponsor_in_office === opt.value ? 'border-brand-500 bg-brand-50' : 'border-gray-200 hover:border-gray-300'}`}>
                        <input type="radio" name="sponsor_in_office" checked={form.sponsor_in_office === opt.value} onChange={() => setForm(f => ({ ...f, sponsor_in_office: opt.value, sponsor_id: '', sponsor_search: '' }))} className="hidden" />
                        <div className={`w-4 h-4 rounded-full border-2 flex-shrink-0 ${form.sponsor_in_office === opt.value ? 'border-brand-500 bg-brand-500' : 'border-gray-300'}`} />
                        <span className="text-sm font-medium">{opt.label}</span>
                      </label>
                    ))}
                  </div>
                </div>

                {/* Show search only if sponsor is in office */}
                {form.sponsor_in_office === true && (
                  <div>
                    <label className="label">Search your sponsor by ID or name *</label>
                    <input
                      className="input"
                      value={form.sponsor_search}
                      onChange={e => {
                        setForm(f => ({ ...f, sponsor_search: e.target.value, sponsor_id: '' }))
                        searchSponsor(e.target.value)
                      }}
                      placeholder="e.g. GRN-001 or John Doe"
                    />
                    {sponsorOptions.length > 0 && (
                      <div className="mt-1 border border-gray-200 rounded-lg overflow-hidden shadow-sm">
                        {sponsorOptions.map(s => (
                          <button key={s.id} type="button"
                            onClick={() => { setForm(f => ({ ...f, sponsor_id: s.id, sponsor_search: `${s.full_name} (${s.member_id})` })); setSponsorOptions([]) }}
                            className="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 border-b border-gray-100 last:border-0">
                            <span className="font-medium">{s.full_name}</span>
                            <span className="text-gray-400 ml-2">{s.member_id}</span>
                          </button>
                        ))}
                      </div>
                    )}
                    {form.sponsor_id && <p className="text-green-600 text-xs mt-1.5 font-medium">✓ Sponsor selected</p>}
                  </div>
                )}

                {/* If sponsor not in office */}
                {form.sponsor_in_office === false && (
                  <div className="bg-amber-50 border border-amber-200 rounded-lg px-4 py-3 text-sm text-amber-700">
                    No problem — your sponsor will be noted as external. You can proceed without a sponsor ID.
                  </div>
                )}

                {error && (
                  <div className="bg-red-50 text-red-700 border border-red-200 rounded-lg px-4 py-3 text-sm">{error}</div>
                )}
              </div>
            )}

            {error && step < 3 && (
              <div className="bg-red-50 text-red-700 border border-red-200 rounded-lg px-4 py-3 text-sm mt-4">{error}</div>
            )}

            <div className="flex gap-3 mt-6">
              {step > 1 && (
                <button type="button" onClick={() => { setStep(s => s - 1); setError('') }} className="btn-secondary flex-1">Back</button>
              )}
              <button type="submit" className="btn-primary flex-1 py-3" disabled={loading}>
                {step < 3 ? 'Continue' : loading ? 'Creating Account...' : 'Create Account'}
              </button>
            </div>
          </form>

          <p className="text-center text-sm text-gray-500 mt-6">
            Already have an account?{' '}
            <Link href="/login" className="text-brand-600 font-semibold hover:underline">Sign in</Link>
          </p>
        </div>
      </div>
    </div>
  )
}
