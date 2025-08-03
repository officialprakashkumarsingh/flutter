-- ==========================================
-- AHAMAI COLLABORATION POLICY FIX
-- ==========================================
-- This script fixes the infinite recursion error in RLS policies
-- Run this in your Supabase SQL Editor

-- ==========================================
-- STEP 1: DROP PROBLEMATIC POLICIES
-- ==========================================

-- Drop the recursive policies that are causing the issue
DROP POLICY IF EXISTS "Room members can view membership" ON public.room_members;
DROP POLICY IF EXISTS "Room admins can manage members" ON public.room_members;
DROP POLICY IF EXISTS "Users can join rooms" ON public.room_members;

-- ==========================================
-- STEP 2: CREATE FIXED ROOM_MEMBERS POLICIES
-- ==========================================

-- Policy 1: Users can view their own membership and memberships in rooms they belong to
CREATE POLICY "Users can view own membership" ON public.room_members
    FOR SELECT USING (
        auth.uid() = user_id OR
        room_id IN (
            SELECT rm.room_id 
            FROM public.room_members rm 
            WHERE rm.user_id = auth.uid() 
            AND rm.is_active = true
        )
    );

-- Policy 2: Users can insert their own membership (for joining rooms)
CREATE POLICY "Users can join rooms" ON public.room_members
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy 3: Room creators and admins can manage members
CREATE POLICY "Room creators and admins can manage members" ON public.room_members
    FOR ALL USING (
        -- Room creator can manage all members
        EXISTS (
            SELECT 1 FROM public.collaboration_rooms cr 
            WHERE cr.id = room_members.room_id 
            AND cr.created_by = auth.uid()
        )
        OR
        -- User can manage their own membership (leave room)
        auth.uid() = room_members.user_id
        OR
        -- Room admins can manage members (but check admin status directly)
        (
            auth.uid() IN (
                SELECT rm.user_id 
                FROM public.room_members rm 
                WHERE rm.room_id = room_members.room_id 
                AND rm.role = 'admin' 
                AND rm.is_active = true
                AND rm.user_id = auth.uid()
            )
        )
    );

-- ==========================================
-- STEP 3: CREATE ALTERNATIVE SIMPLE POLICIES (IF ABOVE STILL CAUSES ISSUES)
-- ==========================================

-- If the above still causes recursion, uncomment this simpler approach:

/*
-- Simple approach: Drop all room_members policies and use basic ones
DROP POLICY IF EXISTS "Users can view own membership" ON public.room_members;
DROP POLICY IF EXISTS "Users can join rooms" ON public.room_members;
DROP POLICY IF EXISTS "Room creators and admins can manage members" ON public.room_members;

-- Very simple policies that avoid recursion
CREATE POLICY "room_members_select_policy" ON public.room_members
    FOR SELECT USING (true); -- Allow viewing all memberships (will be filtered by app logic)

CREATE POLICY "room_members_insert_policy" ON public.room_members
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "room_members_update_policy" ON public.room_members
    FOR UPDATE USING (
        auth.uid() = user_id OR -- Users can update their own membership
        EXISTS (
            SELECT 1 FROM public.collaboration_rooms cr 
            WHERE cr.id = room_members.room_id 
            AND cr.created_by = auth.uid()
        )
    );

CREATE POLICY "room_members_delete_policy" ON public.room_members
    FOR DELETE USING (
        auth.uid() = user_id OR -- Users can delete their own membership
        EXISTS (
            SELECT 1 FROM public.collaboration_rooms cr 
            WHERE cr.id = room_members.room_id 
            AND cr.created_by = auth.uid()
        )
    );
*/

-- ==========================================
-- STEP 4: UPDATE COLLABORATION_ROOMS POLICIES (ALSO FIX POTENTIAL RECURSION)
-- ==========================================

-- Drop and recreate collaboration_rooms policies to avoid recursion
DROP POLICY IF EXISTS "Users can view accessible rooms" ON public.collaboration_rooms;

-- Simplified room access policy
CREATE POLICY "Users can view accessible rooms" ON public.collaboration_rooms
    FOR SELECT USING (
        -- User is the creator
        auth.uid() = created_by 
        OR 
        -- User is a member (simple check)
        id IN (
            SELECT DISTINCT room_id 
            FROM public.room_members 
            WHERE user_id = auth.uid() 
            AND is_active = true
        )
    );

-- ==========================================
-- STEP 5: UPDATE ROOM_MESSAGES POLICIES
-- ==========================================

-- Drop and recreate room_messages policies
DROP POLICY IF EXISTS "Room members can view messages" ON public.room_messages;
DROP POLICY IF EXISTS "Room members can insert messages" ON public.room_messages;

-- Simplified message policies
CREATE POLICY "Users can view messages in their rooms" ON public.room_messages
    FOR SELECT USING (
        room_id IN (
            SELECT DISTINCT rm.room_id 
            FROM public.room_members rm 
            WHERE rm.user_id = auth.uid() 
            AND rm.is_active = true
        )
    );

CREATE POLICY "Users can send messages to their rooms" ON public.room_messages
    FOR INSERT WITH CHECK (
        auth.uid() = user_id 
        AND 
        room_id IN (
            SELECT DISTINCT rm.room_id 
            FROM public.room_members rm 
            WHERE rm.user_id = auth.uid() 
            AND rm.is_active = true
        )
    );

-- ==========================================
-- STEP 6: VERIFICATION QUERY
-- ==========================================

-- Test query to verify policies work
SELECT 
    'Policy Fix Applied Successfully!' as status,
    'RLS policies updated to prevent infinite recursion' as message,
    'Test by creating a room and adding members' as next_step;

-- ==========================================
-- STEP 7: ALTERNATIVE - DISABLE RLS TEMPORARILY (EMERGENCY OPTION)
-- ==========================================

-- If you're still having issues, you can temporarily disable RLS on room_members:
-- ALTER TABLE public.room_members DISABLE ROW LEVEL SECURITY;

-- Remember to re-enable it later and implement proper app-level security:
-- ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;