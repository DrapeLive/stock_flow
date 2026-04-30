from rest_framework.views import APIView
from rest_framework.response import Response
from django.db.models import Count, Sum, Avg, F, ExpressionWrapper, DurationField
from django.db.models.functions import TruncDate
from django.utils import timezone
from datetime import timedelta, datetime
from apps.orders.models import Order, OrderItem, OrderLog
from apps.agents.models import Agent
from apps.accounts.permissions import IsAdmin, admin_business


class AdminDashboardView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        biz = request.user.business
        order_qs = Order.objects.filter(items__item_type=biz).distinct() if biz else Order.objects.all()
        data = {s.lower(): order_qs.filter(status=s).count() for s, _ in Order.STATUS_CHOICES}

        agents = []
        for agent in Agent.objects.all():
            customers_count = agent.customers.filter(order__items__item_type=biz).distinct().count() if biz else agent.customers.count()
            agents.append({
                "agent": agent.user.username,
                "customers": customers_count
            })

        return Response({
            "order_summary": data,
            "agents": agents
        })


class AdminAnalyticsView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        biz = admin_business(request.user)

        from_date = request.query_params.get('from')
        to_date = request.query_params.get('to')

        now = timezone.now()
        if not to_date:
            to_date = now.date().isoformat()
        if not from_date:
            from_date = (now - timedelta(days=30)).date().isoformat()

        order_qs = Order.objects.all()
        if biz:
            order_qs = order_qs.filter(items__item_type=biz).distinct()

        order_qs = order_qs.filter(
            created_at__date__gte=from_date,
            created_at__date__lte=to_date
        )

        kpis = {
            'total': order_qs.count(),
            'draft': order_qs.filter(status='DRAFT').count(),
            'pending': order_qs.filter(status='PENDING').count(),
            'editing': order_qs.filter(status='EDITING').count(),
            'packed': order_qs.filter(status='PACKED').count(),
            'dispatched': order_qs.filter(status='DISPATCHED').count(),
        }

        trend = (
            order_qs
            .annotate(day=TruncDate('created_at'))
            .values('day')
            .annotate(count=Count('id', distinct=True))
            .order_by('day')
        )

        top_customers = (
            order_qs
            .values('customer_id', 'customer__name')
            .annotate(count=Count('id', distinct=True))
            .order_by('-count')[:10]
        )

        top_agents = (
            order_qs
            .values('agent_id', 'agent__user__username')
            .annotate(count=Count('id', distinct=True))
            .order_by('-count')[:10]
        )

        top_items = (
            OrderItem.objects
            .filter(order__in=order_qs)
            .values('item_name')
            .annotate(qty=Sum('quantity'))
            .order_by('-qty')[:10]
        )

        dispatched_in_range = order_qs.filter(status='DISPATCHED')
        dispatch_times = []
        for order in dispatched_in_range:
            log = OrderLog.objects.filter(
                order=order,
                action='DISPATCHED'
            ).order_by('-created_at').first()
            if log:
                delta = log.created_at - order.created_at
                dispatch_times.append(delta.total_seconds() / 3600)

        if dispatch_times:
            avg_dispatch = sum(dispatch_times) / len(dispatch_times)
            sorted_times = sorted(dispatch_times)
            median_dispatch = sorted_times[len(sorted_times) // 2]
            within_24h = sum(1 for t in dispatch_times if t <= 24) / len(dispatch_times) * 100
        else:
            avg_dispatch = None
            median_dispatch = None
            within_24h = None

        time_metrics = {
            'avg_dispatch_hours': avg_dispatch,
            'median_dispatch_hours': median_dispatch,
            'dispatched_within_24h_pct': within_24h,
        }

        return Response({
            'kpis': kpis,
            'trend': list(trend),
            'top_customers': [
                {'id': c['customer_id'], 'name': c['customer__name'], 'count': c['count']}
                for c in top_customers
            ],
            'top_agents': [
                {'id': a['agent_id'], 'username': a['agent__user__username'], 'count': a['count']}
                for a in top_agents
            ],
            'top_items': [
                {'name': i['item_name'], 'qty': i['qty']}
                for i in top_items
            ],
            'time_metrics': time_metrics,
        })