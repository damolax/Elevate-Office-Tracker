import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

const SESSION_LOOKUP_TIMEOUT_MS = 1500

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
  // This keeps landing/scanner/API paths available even if Supabase is slow.
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

  // This middleware is a routing convenience, not the authorization boundary.
  // AppLayout validates protected requests with auth.getUser() on the server.
  // getSession() is normally cookie-local, but an expired session can trigger a
  // refresh. Bound the check so a slow Supabase dependency can never consume
  // Vercel's middleware execution window. On timeout we fail open to AppLayout,
  // which still denies unauthenticated access authoritatively.
  let hasSession: boolean | null = null
  try {
    const result = await Promise.race([
      supabase.auth.getSession().then(({ data }) => Boolean(data.session)),
      new Promise<null>(resolve => setTimeout(() => resolve(null), SESSION_LOOKUP_TIMEOUT_MS)),
    ])
    hasSession = result
  } catch (error) {
    console.warn('Middleware session lookup failed; deferring auth to AppLayout', error)
    hasSession = null
  }

  if (hasSession === false && !isPublic) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  if (hasSession === true && (path === '/login' || path === '/signup')) {
    return NextResponse.redirect(new URL('/dashboard', request.url))
  }

  return response
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
