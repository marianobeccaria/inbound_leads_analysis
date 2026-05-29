import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd


DATABASE = "INBOUND_LEADS"
SCHEMA = "DBT_DEV_GOLD"

RATE_COLUMNS = {
    "SHOW_RATE",
    "TRIAGE_SET_RATE",
    "OFFER_RATE",
    "SALE_RATE",
    "DIAL_TO_SET_RATE",
    "SET_TO_SHOW_RATE",
    "SHOW_TO_SALE_RATE",
    "STRATEGY_CALL_PERCENTAGE",
}
CURRENCY_COLUMNS = {
    "TOTAL_CONTRACT_VALUE",
    "TOTAL_CASH_COLLECTED",
    "AVERAGE_ORDER_VALUE",
    "AVERAGE_CONTRACT_VALUE",
}

st.set_page_config(page_title="Inbound Leads Analytics", layout="wide")
st.title("Inbound Leads Analytics")

session = get_active_session()


def query_table(table_name):
    return session.sql(f"select * from {DATABASE}.{SCHEMA}.{table_name}").to_pandas()


def format_currency(value):
    return f"${value:,.0f}"


def format_percent(numerator, denominator):
    if denominator in (0, None):
        return "0.0%"
    return f"{numerator / denominator:.1%}"


def sorted_unique_values(dataframe, column_name):
    if column_name not in dataframe.columns:
        return []
    return sorted(dataframe[column_name].dropna().unique().tolist())


def filter_by_selection(dataframe, column_name, selected_values):
    if not selected_values or column_name not in dataframe.columns:
        return dataframe
    return dataframe[dataframe[column_name].isin(selected_values)]

def normalize_report_date(dataframe):
    if "REPORT_DATE" not in dataframe.columns:
        return dataframe

    dataframe = dataframe.copy()
    dataframe["REPORT_DATE"] = pd.to_datetime(dataframe["REPORT_DATE"]).dt.date
    return dataframe


def get_global_date_bounds(*dataframes):
    dates = []
    for dataframe in dataframes:
        if "REPORT_DATE" in dataframe.columns and not dataframe.empty:
            dates.extend(dataframe["REPORT_DATE"].dropna().tolist())

    if not dates:
        return None, None

    return min(dates), max(dates)


def filter_by_date_range(dataframe, start_date, end_date):
    if "REPORT_DATE" not in dataframe.columns or start_date is None or end_date is None:
        return dataframe

    return dataframe[
        (dataframe["REPORT_DATE"] >= start_date)
        & (dataframe["REPORT_DATE"] <= end_date)
    ]


def display_table(dataframe, sort_column=None, ascending=False):
    display_df = dataframe.copy()
    if sort_column in display_df.columns:
        display_df = display_df.sort_values(sort_column, ascending=ascending)

    percent_columns = [col for col in display_df.columns if col in RATE_COLUMNS]
    for col in percent_columns:
        display_df[col] = display_df[col] * 100

    column_config = {
        col: st.column_config.NumberColumn(col, format="%.1f%%")
        for col in percent_columns
    }
    column_config.update(
        {
            col: st.column_config.NumberColumn(col, format="$%.0f")
            for col in display_df.columns
            if col in CURRENCY_COLUMNS
        }
    )

    st.dataframe(display_df, use_container_width=True, column_config=column_config)


def bar_chart_or_empty(dataframe, x_column, y_column):
    if dataframe.empty:
        st.info("No rows match the selected filters.")
        return
    st.bar_chart(dataframe, x=x_column, y=y_column)


inbound = query_table("RPT_INBOUND_SETTER")
outbound = query_table("RPT_OUTBOUND_SETTER")
closer = query_table("RPT_CLOSER")
objections = query_table("RPT_OBJECTIONS_FACED")

inbound = normalize_report_date(inbound)
outbound = normalize_report_date(outbound)
closer = normalize_report_date(closer)
objections = normalize_report_date(objections)

with st.sidebar:
    st.header("Filters")

    min_date, max_date = get_global_date_bounds(inbound, outbound, closer, objections)

    if min_date and max_date:
        selected_date_range = st.date_input(
            "Date range",
            value=(min_date, max_date),
            min_value=min_date,
            max_value=max_date,
        )
    else:
        selected_date_range = None

if selected_date_range and len(selected_date_range) == 2:
    start_date, end_date = selected_date_range
    inbound = filter_by_date_range(inbound, start_date, end_date)
    outbound = filter_by_date_range(outbound, start_date, end_date)
    closer = filter_by_date_range(closer, start_date, end_date)
    objections = filter_by_date_range(objections, start_date, end_date)

with st.sidebar:
    selected_inbound_setters = st.multiselect(
        "Inbound setters",
        sorted_unique_values(inbound, "SETTER_NAME"),
    )
    selected_outbound_setters = st.multiselect(
        "Outbound setters",
        sorted_unique_values(outbound, "SETTER_NAME"),
    )
    selected_closers = st.multiselect(
        "Closers",
        sorted_unique_values(closer, "CLOSER_NAME"),
    )

inbound = filter_by_selection(inbound, "SETTER_NAME", selected_inbound_setters)
outbound = filter_by_selection(outbound, "SETTER_NAME", selected_outbound_setters)
closer = filter_by_selection(closer, "CLOSER_NAME", selected_closers)

total_sales = int(
    inbound["TOTAL_SALES"].fillna(0).sum()
    + outbound["TOTAL_SALES"].fillna(0).sum()
)
total_contract_value = float(
    inbound["TOTAL_CONTRACT_VALUE"].fillna(0).sum()
    + outbound["TOTAL_CONTRACT_VALUE"].fillna(0).sum()
)
total_cash_collected = float(
    inbound["TOTAL_CASH_COLLECTED"].fillna(0).sum()
    + outbound["TOTAL_CASH_COLLECTED"].fillna(0).sum()
)
cash_collection_rate = (
    total_cash_collected / total_contract_value
    if total_contract_value else 0
)

inbound_booked = int(inbound["INBOUND_BOOKED"].fillna(0).sum())
inbound_taken = int(inbound["INBOUND_TAKEN"].fillna(0).sum())
triage_set = int(inbound["TRIAGE_SET"].fillna(0).sum())
outbound_calls = int(outbound["TOTAL_OUTBOUND_CALLS"].fillna(0).sum())
outbound_set = int(outbound["OUTBOUND_SET"].fillna(0).sum())
closer_calls_booked = int(closer["CALLS_BOOKED"].fillna(0).sum())
closer_shows = int(closer["SHOWS"].fillna(0).sum())
closer_sales = int(closer["SALES"].fillna(0).sum())

kpi_1, kpi_2, kpi_3 = st.columns(3)
kpi_1.metric("Total Sales", f"{total_sales:,}")
kpi_2.metric("Contract Value", format_currency(total_contract_value))
kpi_3.metric("Cash Collected", format_currency(total_cash_collected))

kpi_4, kpi_5, kpi_6 = st.columns(3)
kpi_4.metric("Cash Collection Rate", f"{cash_collection_rate:.1%}")
kpi_5.metric("Inbound Triage Set Rate", format_percent(triage_set, inbound_taken))
kpi_6.metric("Closer Show-to-Sale Rate", format_percent(closer_sales, closer_shows))

tab_summary, tab_inbound, tab_outbound, tab_closer, tab_objections = st.tabs(
    ["Executive Summary", "Inbound Setters", "Outbound Setters", "Closers", "Objections"]
)

with tab_summary:
    st.subheader("Funnel Snapshot")
    summary_1, summary_2, summary_3, summary_4 = st.columns(4)
    summary_1.metric("Inbound Booked", f"{inbound_booked:,}")
    summary_2.metric("Inbound Taken", f"{inbound_taken:,}")
    summary_3.metric("Outbound Calls", f"{outbound_calls:,}")
    summary_4.metric("Strategy Calls Booked", f"{closer_calls_booked:,}")

    rate_1, rate_2, rate_3, rate_4 = st.columns(4)
    rate_1.metric("Inbound Show Rate", format_percent(inbound_taken, inbound_booked))
    rate_2.metric("Outbound Dial-to-Set", format_percent(outbound_set, outbound_calls))
    rate_3.metric("Closer Show Rate", format_percent(closer_shows, closer_calls_booked))
    rate_4.metric("Closer Close Rate", format_percent(closer_sales, closer_shows))

    st.subheader("Top Objections")
    top_objections = objections.sort_values("OBJECTION_COUNT", ascending=False).head(10)
    bar_chart_or_empty(top_objections, "OBJECTION_CATEGORY", "OBJECTION_COUNT")

with tab_inbound:
    st.subheader("Inbound Setter Performance")
    inbound_sorted = inbound.sort_values("TOTAL_SALES", ascending=False)
    bar_chart_or_empty(inbound_sorted, "SETTER_NAME", "TOTAL_SALES")
    display_table(inbound, sort_column="TOTAL_SALES")

with tab_outbound:
    st.subheader("Outbound Setter Performance")
    outbound_sorted = outbound.sort_values("OUTBOUND_SET", ascending=False)
    bar_chart_or_empty(outbound_sorted, "SETTER_NAME", "OUTBOUND_SET")
    display_table(outbound, sort_column="OUTBOUND_SET")

with tab_closer:
    st.subheader("Closer Performance")
    closer_sorted = closer.sort_values("SALES", ascending=False)
    bar_chart_or_empty(closer_sorted, "CLOSER_NAME", "SALES")
    display_table(closer, sort_column="SALES")

with tab_objections:
    st.subheader("Objections Faced")
    objections_sorted = objections.sort_values("OBJECTION_COUNT", ascending=False)
    bar_chart_or_empty(objections_sorted, "OBJECTION_CATEGORY", "OBJECTION_COUNT")
    display_table(objections, sort_column="OBJECTION_COUNT")
