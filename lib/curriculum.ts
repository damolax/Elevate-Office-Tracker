// =============================================
// ELEVATE OFFICE — 90-DAY CURRICULUM
// =============================================

export const DAILY_SCHEDULE = {
  day: [
    { time: '12:00 – 12:20', activity: 'Excitement' },
    { time: '12:20 – 12:45', activity: 'Book Reading' },
    { time: '12:45 – 13:00', activity: '1st Break' },
    { time: '13:00 – 13:45', activity: 'Basics' },
    { time: '13:45 – 14:00', activity: '2nd Break' },
    { time: '14:00 – 15:30', activity: 'Training Resumes' },
    { time: '15:30 – 16:30', activity: 'Practicals' },
    { time: '16:30 – 17:00', activity: 'Evaluation' },
  ],
  night: [
    { time: '10:00 – 10:10', activity: 'Excitement' },
    { time: '10:10 – 10:30', activity: 'Book Reading' },
    { time: '10:30 – 10:45', activity: '1st Break' },
    { time: '10:45 – 11:30', activity: 'Basics' },
    { time: '11:30 – 11:45', activity: '2nd Break' },
    { time: '11:45 – 01:00', activity: 'Training Resumes' },
    { time: '01:00 – 02:00', activity: 'Practicals' },
    { time: '02:30+',        activity: 'Sleep Time' },
  ],
}

export const WEEK_SKILLS_7_12 = [
  'Wix', 'Shopify and Dropshipping', 'Email Marketing',
  'Social Media Marketing', 'WordPress', 'Video Editing',
  'Copy/Content Writing', 'Project Management', 'Prompt Engineering',
  'Ads', 'Local SEO, Off Page SEO', 'Sales Funnel', 'Landing Page',
]

export interface WeekCurriculum {
  week: number
  phase: number
  phase_title: string
  title: string
  focus: string
  assessments: string[]
}

export const CURRICULUM: WeekCurriculum[] = [
  // PHASE 1 — Weeks 1–4
  {
    week: 1, phase: 1, phase_title: 'Foundation: Orientation, Design & Outreach',
    title: 'Netroversity & Orientation',
    focus: 'Full understanding of F.H.G.T business models and Network Marketing fundamentals.',
    assessments: [
      'Write 20 reasons for wanting to do and build this business',
      'Inform someone about your business with proof',
    ],
  },
  {
    week: 2, phase: 1, phase_title: 'Foundation: Orientation, Design & Outreach',
    title: 'Canva Class',
    focus: 'Understanding Canva basics and using video resources to deepen your skills.',
    assessments: [
      'Write 2 pages: What is a website and what is it used for?',
      'Design a website on Canva over the weekend',
      'Follow at least 5 top Network Marketers on your preferred social media platform',
    ],
  },
  {
    week: 3, phase: 1, phase_title: 'Foundation: Orientation, Design & Outreach',
    title: 'Squarespace Website Design',
    focus: 'Mastering the drag-and-drop Squarespace platform through guided video learning.',
    assessments: [
      'Design a 4-page website on Squarespace (Home, About, Contact, Services)',
      'Draw your 6-month plan — what you want to achieve in the business',
    ],
  },
  {
    week: 4, phase: 1, phase_title: 'Foundation: Orientation, Design & Outreach',
    title: 'Scouting Class',
    focus: 'Learn how to find clients for your services. Understand which platforms to scout and whom to target. Have at least one active downline in the office.',
    assessments: [
      'Write a report on outreach and different ways to conduct it',
      'What other platforms can you scout apart from the ones you were taught? Is there a way to get someone that is most likely not being scouted? If so, how? Can Nigerians use it?',
      'Read Part One of Business of the 21st Century',
      'Follow at least 2 channels about Fiverr across all social media platforms',
    ],
  },
  // PHASE 2 — Weeks 5–8
  {
    week: 5, phase: 2, phase_title: 'Execution: Fiverr Mastery & Active Scouting',
    title: 'Fiverr Basics',
    focus: 'Learn Terms & Conditions, account creation, gig setup, and optimization. Understand how to manage both Nigerian and foreign Fiverr accounts.',
    assessments: [
      'Have all requirements ready to create your first gig and account',
      'Write a one-page report on optimizing your gig for ranking',
      'Read Part Two of Business of the 21st Century',
      'Watch and write a report on "How to Communicate Effectively on Fiverr"',
    ],
  },
  {
    week: 6, phase: 2, phase_title: 'Execution: Fiverr Mastery & Active Scouting',
    title: 'Create & Scout',
    focus: 'Create one account with 4 gigs daily. Scout actively for clients.',
    assessments: [
      'Read Part Three of Business of the 21st Century',
      'Watch and write a report on "Tactics & Strategies on Pricing on Fiverr"',
    ],
  },
  {
    week: 7, phase: 2, phase_title: 'Execution: Fiverr Mastery & Active Scouting',
    title: 'Scale & Scout',
    focus: 'Continue creating one account with 4 gigs daily. Scout actively.',
    assessments: [
      'Read Part Four of Business of the 21st Century',
      'Watch and write a report on "Tactics & Strategies on Negotiations on Fiverr"',
    ],
  },
  {
    week: 8, phase: 2, phase_title: 'Execution: Fiverr Mastery & Active Scouting',
    title: 'Skill Development & Team Growth',
    focus: 'Learn any general skill or service based on your situation. Scout actively. Further assignments will be based on the skill you are learning.',
    assessments: [
      'Read Chapters 1–5 of Go Pro',
      'Watch and write a report on "Tactics & Strategies on Pricing on Fiverr"',
      'Should have 2 active team members — either personally recruited or built through your team\'s collective effort',
    ],
  },
  // PHASE 3 — Weeks 9–12
  {
    week: 9, phase: 3, phase_title: 'Momentum: Specialization, Team Building & Your $500 Target',
    title: 'Week 9 — Specialization',
    focus: 'Continue skill development and active scouting. Assignments based on your chosen skill.',
    assessments: [
      'Read Chapters 6 & 7 of Go Pro',
      'Watch and write a report on "Tactics & Strategies on Pricing on Fiverr"',
    ],
  },
  {
    week: 10, phase: 3, phase_title: 'Momentum: Specialization, Team Building & Your $500 Target',
    title: 'Week 10 — Momentum',
    focus: 'Continue skill development and active scouting. Assignments based on your chosen skill.',
    assessments: [
      'Read Chapters 8 & 9 of Go Pro',
    ],
  },
  {
    week: 11, phase: 3, phase_title: 'Momentum: Specialization, Team Building & Your $500 Target',
    title: 'Week 11 — Refinement',
    focus: 'Continue skill development. Assignments based on your chosen skill.',
    assessments: [
      'Read Chapters 10–12 of Go Pro',
    ],
  },
  {
    week: 12, phase: 3, phase_title: 'Momentum: Specialization, Team Building & Your $500 Target',
    title: 'Week 12 — Graduation Week',
    focus: 'Final skill refinement. You should now be earning and building your team.',
    assessments: [
      'Watch videos on Passive Income, Wealth Formation & Earnings',
      'Should have at least 4 active team members — either personally recruited or through your team\'s collective effort',
    ],
  },
]

export function getWeekCurriculum(weekNumber: number): WeekCurriculum | null {
  return CURRICULUM.find(w => w.week === weekNumber) ?? null
}

export const WEEK_RULES = {
  min_attendance_days: 4,       // out of 5
  office_days_per_week: 5,      // Mon-Fri
  assessment_deadline_day: 1,   // Monday (0=Sun, 1=Mon)
  assessment_deadline_time: '11:45',
}
