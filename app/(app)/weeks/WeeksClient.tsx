'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { format, parseISO, isToday, isPast } from 'date-fns'
import { CURRICULUM, DAILY_SCHEDULE, WEEK_SKILLS_7_12, getWeekCurriculum, WEEK_RULES } from '@/lib/curriculum'
import { CheckCircle, XCircle, Clock, BookOpen, Calendar, Users, ChevronRight, Award, AlertTriangle, Check, X } from 'lucide-react'
import ViewAsBanner from '@/components/admin/ViewAsBanner'

type Tab = 'overview' | 'curriculum' | 'schedule' | 'history' | 'admin'

export default function WeeksClient({
  profile, isAdmin, isTrackable, currentWeekNumber,
  myWeekAttendance, myAllAttendance, myAssessments, myAdvancementLog,
  allMembers, allAssessments, allWeekAttendance, workDays, weekStartStr, weekEndStr,
  isViewingAs, viewAsName,
}: {
  profile: any; isAdmin: boolean; isTrackable: boolean; currentWeekNumber: number
  myWeekAttendance: any[]; myAllAttendance: any[]; myAssessments: any[]
  myAdvancementLog: any[]; allMembers: any[]; allAssessments: any[]
  allWeekAttendance: any[]; workDays: string[]; weekStartStr: string; weekEndStr: string
  isViewingAs?: boolean; viewAsName?: string | null
}) {
  const [tab, setTab] = useState<Tab>(isTrackable ? 'overview' : 'admin')
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [loading, setLoading] = useState<string | null>(null)

  const curriculum = getWeekCurriculum(currentWeekNumber)
  const myAttendedDays = myWeekAttendance.map(a => a.date)
  const daysPresent = myAttendedDays.length
  const daysMissed = workDays.filter(d => {
    const date = parseISO(d)
    return isPast(date) && !isToday(date) && !myAttendedDays.includes(d)
  })
  const daysRemaining = workDays.filter(d => {
    const date = parseISO(d)
    return !isPast(date) || isToday(date)
  })
  const currentAssessment = myAssessments.find(a => a.week_number === currentWeekNumber)
  const needsMoreDays = daysPresent < WEEK_RULES.min_attendance_days
  const canStillPass = daysPresent + daysRemaining.length >= WEEK_RULES.min_attendance_days

  // Admin: build member summary
  const memberSummary = allMembers.map(m => {
    const attended = allWeekAttendance.filter(a => a.user_id === m.id).length
    const assessment = allAssessments.find(a => a.user_id === m.id && a.week_number === m.week_number)
    const missedDays = workDays.filter(d => {
      const date = parseISO(d)
      return (isPast(date) && !isToday(date)) &&
        !allWeekAttendance.find(a => a.user_id === m.id && a.date === d)
    })
    const atRisk = attended < 3 && workDays.filter(d => !isPast(parseISO(d)) || isToday(parseISO(d))).length < (WEEK_RULES.min_attendance_days - attended)
    return { ...m, attended, missedDays: missedDays.length, assessment, atRisk }
  })

  async function markAssessmentSubmitted(userId: string, weekNum: number) {
    setLoading(`submit-${userId}-${weekNum}`)
    const supabase = createClient()
    await supabase.from('week_assessments').upsert({
      user_id: userId, week_number: weekNum,
      submitted: true, submitted_at: new Date().toISOString(),
    }, { onConflict: 'user_id,week_number' })
    setMsg({ type: 'success', text: 'Assessment marked as submitted' })
    setLoading(null)
    setTimeout(() => window.location.reload(), 800)
  }

  async function gradeAssessment(userId: string, weekNum: number, grade: string) {
    setLoading(`grade-${userId}-${weekNum}`)
    const supabase = createClient()
    await supabase.from('week_assessments').upsert({
      user_id: userId, week_number: weekNum,
      submitted: true, graded: true, grade,
      graded_at: new Date().toISOString(), graded_by: profile.id,
    }, { onConflict: 'user_id,week_number' })
    setMsg({ type: 'success', text: `Assessment graded: ${grade}` })
    setLoading(null)
    setTimeout(() => window.location.reload(), 800)
  }

  async function advanceMember(userId: string, fromWeek: number, action: 'advanced' | 'repeated' | 'pardoned', notes = '') {
    setLoading(`advance-${userId}`)
    const supabase = createClient()
    const toWeek = action === 'repeated' ? fromWeek : Math.min(fromWeek + 1, 12)
    const member = allMembers.find(m => m.id === userId)
    const assessment = allAssessments.find(a => a.user_id === userId && a.week_number === fromWeek)
    const attended = allWeekAttendance.filter(a => a.user_id === userId).length

    // Log the action
    await supabase.from('week_advancement_log').insert({
      user_id: userId, from_week: fromWeek, to_week: toWeek, action,
      attendance_days: attended,
      assessment_submitted: assessment?.submitted ?? false,
      assessment_graded: assessment?.graded ?? false,
      admin_notes: notes, actioned_by: profile.id,
    })

    // Update profile week number
    await supabase.from('profiles').update({ week_number: toWeek, week_confirmed: action !== 'repeated' }).eq('id', userId)

    setMsg({ type: 'success', text: `${member?.full_name} ${action === 'advanced' ? 'advanced to week ' + toWeek : action === 'pardoned' ? 'pardoned and advanced to week ' + toWeek : 'will repeat week ' + fromWeek}` })
    setLoading(null)
    setTimeout(() => window.location.reload(), 1000)
  }

  async function sendAbsenceEmail(userId: string) {
    setLoading(`email-${userId}`)
    try {
      const res = await fetch('/api/absence-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: userId, type: 'manual', admin_id: profile.id }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error)
      setMsg({ type: 'success', text: 'Absence email sent' })
    } catch (e: any) {
      setMsg({ type: 'error', text: e.message })
    }
    setLoading(null)
  }

  const tabs: { id: Tab; label: string }[] = [
    ...(isTrackable ? [
      { id: 'overview' as Tab, label: 'My Week' },
      { id: 'curriculum' as Tab, label: 'Curriculum' },
      { id: 'schedule' as Tab, label: 'Schedule' },
      { id: 'history' as Tab, label: 'My History' },
    ] : []),
    ...(isAdmin ? [{ id: 'admin' as Tab, label: `Members (${allMembers.length})` }] : []),
  ]

  if (!isTrackable && !isAdmin) {
    return (
      <div className="max-w-2xl mx-auto space-y-4">
        {isViewingAs && viewAsName && <ViewAsBanner name={viewAsName} />}
        <div className="card p-8 text-center space-y-2">
          <BookOpen className="w-10 h-10 text-gray-300 mx-auto" />
          <h2 className="text-lg font-semibold text-gray-900">12-Week Program Not Applicable</h2>
          <p className="text-sm text-gray-500">
            The 12-week onboarding program applies to Members, Distributors, and Managers only.
            {profile.status && ` As a ${String(profile.status).replace('_', ' ')}`}, this program doesn&apos;t apply here.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      {isViewingAs && viewAsName && <ViewAsBanner name={viewAsName} />}
      {msg && (
        <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
          {msg.text}
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {tabs.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}>
            {t.label}
          </button>
        ))}
      </div>

      {/* ── MY WEEK OVERVIEW ── */}
      {tab === 'overview' && (
        <div className="space-y-4">
          {/* Week header */}
          <div className="card p-6 bg-gradient-to-r from-brand-900 to-brand-700 text-white border-0">
            <div className="flex items-start justify-between flex-wrap gap-4">
              <div>
                <div className="text-brand-200 text-sm font-medium mb-1">
                  Phase {curriculum?.phase} · {curriculum?.phase_title}
                </div>
                <h1 className="text-2xl font-extrabold">Week {currentWeekNumber} — {curriculum?.title}</h1>
                <p className="text-brand-200 text-sm mt-2 max-w-lg">{curriculum?.focus}</p>
              </div>
              <div className="text-right">
                <div className="text-4xl font-black">{currentWeekNumber}<span className="text-brand-300 text-xl">/12</span></div>
                <div className="text-brand-200 text-xs mt-1">Current Week</div>
              </div>
            </div>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {[
              { label: 'Days Present', value: daysPresent, total: 5, color: daysPresent >= 4 ? 'text-green-600' : 'text-amber-600', bg: daysPresent >= 4 ? 'bg-green-50' : 'bg-amber-50' },
              { label: 'Days Missed', value: daysMissed.length, color: daysMissed.length === 0 ? 'text-green-600' : 'text-red-600', bg: daysMissed.length === 0 ? 'bg-green-50' : 'bg-red-50' },
              { label: 'Assessment', value: currentAssessment?.graded ? 'Graded' : currentAssessment?.submitted ? 'Submitted' : 'Pending', color: currentAssessment?.graded ? 'text-green-600' : currentAssessment?.submitted ? 'text-blue-600' : 'text-amber-600', bg: 'bg-gray-50', isText: true },
              { label: 'Status', value: daysPresent >= 4 && currentAssessment?.graded ? 'On Track' : canStillPass ? 'In Progress' : 'At Risk', color: daysPresent >= 4 && currentAssessment?.graded ? 'text-green-600' : canStillPass ? 'text-brand-600' : 'text-red-600', bg: 'bg-gray-50', isText: true },
            ].map(s => (
              <div key={s.label} className={`card p-4 ${s.bg}`}>
                <div className={`text-2xl font-extrabold ${s.color}`}>{s.value}</div>
                <div className="text-xs text-gray-500 mt-1 font-medium">{s.label}</div>
              </div>
            ))}
          </div>

          {/* Attendance this week */}
          <div className="card p-5">
            <h2 className="section-title mb-4">This Week — {format(parseISO(weekStartStr), 'MMM d')} to {format(parseISO(weekEndStr), 'MMM d, yyyy')}</h2>
            <div className="grid grid-cols-5 gap-2">
              {workDays.map(day => {
                const present = myAttendedDays.includes(day)
                const isPastDay = isPast(parseISO(day)) && !isToday(parseISO(day))
                const isTodayDay = isToday(parseISO(day))
                const dayName = format(parseISO(day), 'EEE')
                const dayNum = format(parseISO(day), 'd')
                return (
                  <div key={day} className={`text-center p-3 rounded-xl border-2 transition-all ${
                    present ? 'bg-green-50 border-green-400' :
                    isTodayDay ? 'bg-brand-50 border-brand-400' :
                    isPastDay ? 'bg-red-50 border-red-200' :
                    'bg-gray-50 border-gray-200'
                  }`}>
                    <div className="text-xs font-semibold text-gray-500">{dayName}</div>
                    <div className="text-lg font-extrabold mt-0.5">{dayNum}</div>
                    <div className="mt-1">
                      {present ? <CheckCircle size={16} className="text-green-500 mx-auto" /> :
                       isTodayDay ? <Clock size={16} className="text-brand-500 mx-auto" /> :
                       isPastDay ? <XCircle size={16} className="text-red-400 mx-auto" /> :
                       <div className="w-4 h-4 rounded-full border-2 border-gray-300 mx-auto" />}
                    </div>
                  </div>
                )
              })}
            </div>

            {!canStillPass && (
              <div className="mt-4 flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
                <AlertTriangle size={16} className="flex-shrink-0 mt-0.5" />
                <span>You have missed too many days this week. You may need to repeat Week {currentWeekNumber}. Contact your SM or the admin.</span>
              </div>
            )}
          </div>

          {/* This week's assessment */}
          {curriculum && isTrackable && (
            <div className="card p-5">
              <div className="flex items-center justify-between mb-4 flex-wrap gap-2">
                <h2 className="section-title">Week {currentWeekNumber} Assessment</h2>
                <div className={`badge ${currentAssessment?.graded ? 'bg-green-100 text-green-700' : currentAssessment?.submitted ? 'bg-blue-100 text-blue-700' : 'bg-amber-100 text-amber-700'}`}>
                  {currentAssessment?.graded ? '✓ Graded' : currentAssessment?.submitted ? '✓ Submitted' : '⏳ Pending Submission'}
                </div>
              </div>

              <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 mb-4 text-sm text-amber-800">
                <strong>Due: Monday before 11:45 AM</strong> — Submit your assessment physically to the admin before this deadline to advance to Week {Math.min(currentWeekNumber + 1, 12)}.
              </div>

              <div className="space-y-2">
                {curriculum.assessments.map((a, i) => (
                  <div key={i} className="flex items-start gap-3 p-3 rounded-lg bg-gray-50 border border-gray-100">
                    <div className={`w-6 h-6 rounded-full flex-shrink-0 flex items-center justify-center text-xs font-bold ${currentAssessment?.graded ? 'bg-green-100 text-green-700' : 'bg-gray-200 text-gray-600'}`}>
                      {currentAssessment?.graded ? '✓' : i + 1}
                    </div>
                    <p className="text-sm text-gray-700 leading-relaxed">{a}</p>
                  </div>
                ))}
              </div>

              {currentAssessment?.grade && (
                <div className="mt-3 p-3 bg-green-50 border border-green-200 rounded-lg text-sm">
                  <span className="font-medium text-green-700">Grade: {currentAssessment.grade}</span>
                  {currentAssessment.admin_notes && <p className="text-green-600 mt-1">{currentAssessment.admin_notes}</p>}
                </div>
              )}
            </div>
          )}

          {/* Advancement requirements */}
          <div className="card p-5">
            <h2 className="section-title mb-4">Requirements to Advance to Week {Math.min(currentWeekNumber + 1, 12)}</h2>
            <div className="space-y-2">
              {[
                { label: `Attend at least 4 out of 5 days this week (${daysPresent}/4)`, done: daysPresent >= 4 },
                { label: 'Submit your assessment before Monday 11:45 AM', done: !!currentAssessment?.submitted },
                { label: 'Assessment graded by admin', done: !!currentAssessment?.graded },
                { label: 'Admin confirms week advancement', done: false },
              ].map((req, i) => (
                <div key={i} className={`flex items-center gap-3 p-3 rounded-lg border ${req.done ? 'bg-green-50 border-green-200' : 'bg-gray-50 border-gray-100'}`}>
                  {req.done ? <Check size={16} className="text-green-600 flex-shrink-0" /> : <div className="w-4 h-4 rounded-full border-2 border-gray-300 flex-shrink-0" />}
                  <span className={`text-sm ${req.done ? 'text-green-700 font-medium' : 'text-gray-600'}`}>{req.label}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ── CURRICULUM ── */}
      {tab === 'curriculum' && (
        <div className="space-y-4">
          <div className="card p-5">
            <h2 className="section-title mb-1">12-Week Curriculum</h2>
            <p className="text-sm text-gray-500 mb-4">Your complete 90-day plan. Complete every assessment every week — no shortcuts, no exceptions.</p>
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 text-sm text-amber-800 mb-4">
              <strong>Non-Negotiable Rule:</strong> Any member absent during any week of this program must repeat that week before advancing. Completing all knowledge modules and assessments each week is the only requirement to unlock the next week. No exceptions.
            </div>
          </div>

          {[1, 2, 3].map(phase => {
            const weeks = CURRICULUM.filter(w => w.phase === phase)
            return (
              <div key={phase} className="card overflow-hidden">
                <div className="bg-brand-900 text-white px-5 py-3">
                  <div className="text-xs text-brand-300 font-semibold uppercase tracking-wider">Phase {phase}</div>
                  <div className="font-bold">{weeks[0].phase_title}</div>
                </div>
                <div className="divide-y divide-gray-100">
                  {weeks.map(w => {
                    const isCurrent = w.week === currentWeekNumber
                    const isPast = w.week < currentWeekNumber
                    const myAssessment = myAssessments.find(a => a.week_number === w.week)
                    return (
                      <div key={w.week} className={`p-5 ${isCurrent ? 'bg-brand-50' : ''}`}>
                        <div className="flex items-start justify-between gap-3 flex-wrap">
                          <div className="flex items-start gap-3 flex-1">
                            <div className={`w-8 h-8 rounded-full flex-shrink-0 flex items-center justify-center text-sm font-extrabold ${
                              isPast ? 'bg-green-100 text-green-700' :
                              isCurrent ? 'bg-brand-600 text-white' :
                              'bg-gray-100 text-gray-400'
                            }`}>
                              {isPast ? '✓' : w.week}
                            </div>
                            <div className="flex-1">
                              <div className="flex items-center gap-2 flex-wrap">
                                <div className="font-bold text-gray-900">Week {w.week} — {w.title}</div>
                                {isCurrent && <span className="badge bg-brand-100 text-brand-700">Current</span>}
                                {myAssessment?.graded && <span className="badge bg-green-100 text-green-700">✓ Graded</span>}
                                {myAssessment?.submitted && !myAssessment?.graded && <span className="badge bg-blue-100 text-blue-700">Submitted</span>}
                              </div>
                              <p className="text-sm text-gray-500 mt-1 leading-relaxed">{w.focus}</p>
                              {(isCurrent || isPast) && (
                                <div className="mt-3 space-y-1">
                                  <div className="text-xs font-semibold text-gray-400 uppercase tracking-wide">Assessments</div>
                                  {w.assessments.map((a, i) => (
                                    <div key={i} className="text-sm text-gray-600 flex items-start gap-2">
                                      <span className="text-gray-300 flex-shrink-0">•</span>
                                      {a}
                                    </div>
                                  ))}
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            )
          })}

          {/* Skills weeks 7-12 */}
          <div className="card p-5">
            <h2 className="section-title mb-3">Skills Taught in Weeks 7–12</h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
              {WEEK_SKILLS_7_12.map(skill => (
                <div key={skill} className="flex items-center gap-2 p-2.5 rounded-lg bg-brand-50 border border-brand-100 text-sm font-medium text-brand-700">
                  <ChevronRight size={14} className="flex-shrink-0" />
                  {skill}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ── SCHEDULE ── */}
      {tab === 'schedule' && (
        <div className="space-y-4">
          <div className="card p-5">
            <h2 className="section-title mb-1">Daily Schedule</h2>
            <p className="text-sm text-gray-500 mb-4">Whether you attend the day or night session, the structure is identical. Arrive on time. Stay focused. Execute without excuses.</p>
            <div className="grid sm:grid-cols-2 gap-4">
              {(['day', 'night'] as const).map(session => (
                <div key={session} className={`rounded-xl overflow-hidden border ${session === 'day' ? 'border-amber-200' : 'border-brand-200'}`}>
                  <div className={`px-4 py-3 font-bold text-sm flex items-center gap-2 ${session === 'day' ? 'bg-amber-50 text-amber-800' : 'bg-brand-900 text-white'}`}>
                    {session === 'day' ? '☀ Day Session' : '🌙 Night Session'}
                  </div>
                  <div className="divide-y divide-gray-100">
                    {DAILY_SCHEDULE[session].map((item, i) => (
                      <div key={i} className="flex justify-between items-center px-4 py-2.5 text-sm">
                        <span className="font-mono text-xs text-gray-400 w-28 flex-shrink-0">{item.time}</span>
                        <span className="text-gray-700 font-medium flex-1 text-right">{item.activity}</span>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
            <div className="mt-4 p-3 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-600">
              <strong>Before going home</strong> — complete your Evaluation. Early prayer is observed for both Muslim and Christian members before going home after night sessions.
            </div>
          </div>
        </div>
      )}

      {/* ── HISTORY ── */}
      {tab === 'history' && (
        <div className="space-y-4">
          <div className="card p-5">
            <h2 className="section-title mb-4">Attendance History</h2>
            {myAllAttendance.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No attendance records yet</p>
            ) : (
              <div className="space-y-2">
                {myAllAttendance.slice(0, 60).map(a => (
                  <div key={a.id} className="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
                    <div>
                      <div className="font-medium text-sm text-gray-900">{format(parseISO(a.date), 'EEEE, MMMM d yyyy')}</div>
                      <div className="text-xs text-gray-400">
                        In: {a.sign_in_time ? format(parseISO(a.sign_in_time), 'h:mm a') : '—'}
                        {a.sign_out_time && ` · Out: ${format(parseISO(a.sign_out_time), 'h:mm a')}`}
                        {a.is_night_session && ' · Night'}
                      </div>
                    </div>
                    <CheckCircle size={16} className="text-green-500" />
                  </div>
                ))}
              </div>
            )}
          </div>

          {myAdvancementLog.length > 0 && (
            <div className="card p-5">
              <h2 className="section-title mb-4">Week Advancement History</h2>
              <div className="space-y-2">
                {myAdvancementLog.map(log => (
                  <div key={log.id} className={`flex items-start gap-3 p-3 rounded-lg border ${
                    log.action === 'advanced' ? 'bg-green-50 border-green-200' :
                    log.action === 'pardoned' ? 'bg-blue-50 border-blue-200' :
                    'bg-amber-50 border-amber-200'
                  }`}>
                    <div className={`text-lg flex-shrink-0 ${log.action === 'advanced' ? 'text-green-600' : log.action === 'pardoned' ? 'text-blue-600' : 'text-amber-600'}`}>
                      {log.action === 'advanced' ? '🎯' : log.action === 'pardoned' ? '🙏' : '🔄'}
                    </div>
                    <div>
                      <div className="font-medium text-sm capitalize">
                        {log.action === 'advanced' ? `Advanced: Week ${log.from_week} → Week ${log.to_week}` :
                         log.action === 'pardoned' ? `Pardoned: Advanced to Week ${log.to_week}` :
                         `Repeated Week ${log.from_week}`}
                      </div>
                      <div className="text-xs text-gray-500 mt-0.5">
                        {format(parseISO(log.created_at), 'MMM d, yyyy')} · {log.attendance_days} days attended
                      </div>
                      {log.admin_notes && <p className="text-xs text-gray-500 mt-1 italic">{log.admin_notes}</p>}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ── ADMIN ── */}
      {tab === 'admin' && isAdmin && (
        <div className="space-y-4">
          <div className="card p-5">
            <h2 className="section-title mb-1">Member Week Tracker</h2>
            <p className="text-sm text-gray-500 mb-4">
              Week runs Monday–Friday. Assessment deadline: Monday 11:45 AM. Min 4 days attendance required to advance.
            </p>
          </div>

          {memberSummary.length === 0 ? (
            <div className="card p-8 text-center text-gray-400 text-sm">No trackable members yet</div>
          ) : (
            <div className="space-y-3">
              {memberSummary.map(m => {
                const weekCurr = getWeekCurriculum(m.week_number)
                return (
                  <div key={m.id} className={`card p-5 ${m.atRisk ? 'border-red-200 bg-red-50/30' : ''}`}>
                    <div className="flex items-start justify-between gap-3 flex-wrap">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl flex items-center justify-center text-white font-bold text-sm flex-shrink-0"
                          style={{ backgroundColor: m.color_groups?.hex_color ?? '#4f46e5' }}>
                          {m.full_name.slice(0, 1)}
                        </div>
                        <div>
                          <div className="font-bold text-gray-900">{m.full_name}</div>
                          <div className="text-xs text-gray-400">{m.member_id} · Week {m.week_number} — {weekCurr?.title}</div>
                        </div>
                      </div>

                      <div className="flex items-center gap-2 flex-wrap">
                        {/* Attendance badge */}
                        <span className={`badge ${m.attended >= 4 ? 'bg-green-100 text-green-700' : m.atRisk ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'}`}>
                          {m.attended}/5 days
                        </span>

                        {/* Assessment badge */}
                        <span className={`badge ${m.assessment?.graded ? 'bg-green-100 text-green-700' : m.assessment?.submitted ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-500'}`}>
                          {m.assessment?.graded ? '✓ Graded' : m.assessment?.submitted ? 'Submitted' : 'No assessment'}
                        </span>

                        {m.atRisk && <span className="badge bg-red-100 text-red-700">⚠ At Risk</span>}
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="mt-4 flex gap-2 flex-wrap">
                      {/* Assessment actions */}
                      {!m.assessment?.submitted && (
                        <button onClick={() => markAssessmentSubmitted(m.id, m.week_number)}
                          disabled={loading === `submit-${m.id}-${m.week_number}`}
                          className="btn-secondary btn-sm">
                          Mark Assessment Submitted
                        </button>
                      )}
                      {m.assessment?.submitted && !m.assessment?.graded && (
                        <div className="flex gap-2">
                          <button onClick={() => gradeAssessment(m.id, m.week_number, 'pass')}
                            disabled={!!loading} className="btn-secondary btn-sm text-green-700 border-green-300">
                            Grade: Pass
                          </button>
                          <button onClick={() => gradeAssessment(m.id, m.week_number, 'excellent')}
                            disabled={!!loading} className="btn-secondary btn-sm text-brand-700 border-brand-300">
                            Grade: Excellent
                          </button>
                          <button onClick={() => gradeAssessment(m.id, m.week_number, 'fail')}
                            disabled={!!loading} className="btn-secondary btn-sm text-red-700 border-red-300">
                            Grade: Fail
                          </button>
                        </div>
                      )}

                      {/* Week advancement */}
                      {m.assessment?.graded && m.attended >= 4 && m.week_number < 12 && (
                        <button onClick={() => advanceMember(m.id, m.week_number, 'advanced')}
                          disabled={loading === `advance-${m.id}`}
                          className="btn-primary btn-sm flex items-center gap-1">
                          <ChevronRight size={14} /> Advance to Week {m.week_number + 1}
                        </button>
                      )}

                      {/* Repeat week */}
                      {(m.atRisk || m.missedDays >= 2) && (
                        <button onClick={() => advanceMember(m.id, m.week_number, 'repeated')}
                          disabled={!!loading}
                          className="btn-secondary btn-sm text-amber-700 border-amber-300">
                          🔄 Repeat Week {m.week_number}
                        </button>
                      )}

                      {/* Pardon */}
                      {(m.atRisk || m.missedDays >= 2) && m.week_number < 12 && (
                        <button onClick={() => advanceMember(m.id, m.week_number, 'pardoned', 'Admin pardon')}
                          disabled={!!loading}
                          className="btn-secondary btn-sm text-blue-700 border-blue-300">
                          🙏 Pardon & Advance
                        </button>
                      )}

                      {/* Send absence email */}
                      {m.missedDays > 0 && (
                        <button onClick={() => sendAbsenceEmail(m.id)}
                          disabled={loading === `email-${m.id}`}
                          className="btn-secondary btn-sm text-gray-600">
                          📧 Send Absence Email
                        </button>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
