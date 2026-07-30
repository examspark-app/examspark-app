-- Auto-leave groups when subscription changes (expire / cancel / plan swap).
-- Product rule: Free → leave all; downgrade → keep newest N by joined_at.
-- Previously only refund_service called fn_trim_group_memberships — monthly
-- expiry / SQL smoke expire did NOT auto-leave. This trigger closes that gap.
--
-- Run once in Supabase SQL Editor (after fn_trim_group_memberships exists).

CREATE OR REPLACE FUNCTION fn_trim_groups_on_subscription_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.fn_trim_group_memberships(NEW.user_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trim_groups_on_subscription_change ON public.user_subscriptions;
CREATE TRIGGER trg_trim_groups_on_subscription_change
  AFTER INSERT OR UPDATE OF status, plan_id, current_period_end
  ON public.user_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION fn_trim_groups_on_subscription_change();

COMMENT ON FUNCTION fn_trim_groups_on_subscription_change IS
  'After any sub change, trim class_memberships to current plan max_groups.';
