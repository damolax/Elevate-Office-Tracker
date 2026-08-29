import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  const path = request.nextUrl.pathname

  const isPublic =
    path === '/' ||
    path === '/login' ||
    path === '/signup' ||
    path === '/pending-approval' ||
    path.startsWith('/auth/') ||
    path.startsWith('/scanner') ||
    path.startsWith('/attendance/scan') ||
    path.startsWith('/api/')

  // Public routes must never wait on an external authentication request.
  // This keeps the landing/login/scanner/API paths available even if Supabase
  // is temporarily slow or unavailable.
  if (isPublic && path !== '/login' && path !== '/signup') {
    return NextResponse.next()
  }

  let response = NextResponse.next({
    request: {
      headers: request.headers,
    },
  })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            request.cookies.set(name, value)
            response.cookies.set(name, value, options)
          })
        },
      },
    }
  )

  // Middleware only needs enough information to route the request. getSession()
  // reads the locally available auth state and avoids the remote Auth request made
  // by getUser(), which can exceed Vercel's middleware execution window.
  // Protected server pages still call getUser() and remain the authority for access.
  const { data: { session } } = await supabase.auth.getSession()
  const hasSession = Boolean(session)

  if (!hasSession && !isPublic) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  if (hasSession && (path === '/login' || path === '/signup')) {
    return NextResponse.redirect(new URL('/dashboard', request.url))
  }

  return response
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
