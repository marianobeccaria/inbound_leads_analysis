import streamlit as st
from snowflake.snowpark.context import get_active_session


DATABASE = "INBOUND_LEADS"
SCHEMA = "DBT_DEV_GOLD"


st.set_page_config(page_title="Inbound Leads Analytics", layout="wide")
st.title("Inbound Leads Analytics")

session = get_active_session()


def query_table(table_name):
    return session.sql(f"select * from {DATABASE}.{SCHEMA}.{table_name}").to_pandas()


inbound = query_table("RPT_INBOUND_SETTER")
outbound = query_table("RPT_OUTBOUND_SETTER")
closer = query_table("RPT_CLOSER")
objections = query_table("RPT_OBJECTIONS_FACED")

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

kpi_1, kpi_2, kpi_3 = st.columns(3)
kpi_1.metric("Total Sales", f"{total_sales:,}")
kpi_2.metric("Contract Value", f"${total_contract_value:,.0f}")
kpi_3.metric("Cash Collected", f"${total_cash_collected:,.0f}")

tab_inbound, tab_outbound, tab_closer, tab_objections = st.tabs(
    ["Inbound Setters", "Outbound Setters", "Closers", "Objections"]
)

with tab_inbound:
    st.subheader("Inbound Setter Performance")
    st.bar_chart(
        inbound.sort_values("TOTAL_SALES", ascending=False),
        x="SETTER_NAME",
        y="TOTAL_SALES",
    )
    st.dataframe(inbound, use_container_width=True)

with tab_outbound:
    st.subheader("Outbound Setter Performance")
    st.bar_chart(
        outbound.sort_values("OUTBOUND_SET", ascending=False),
        x="SETTER_NAME",
        y="OUTBOUND_SET",
    )
    st.dataframe(outbound, use_container_width=True)

with tab_closer:
    st.subheader("Closer Performance")
    st.bar_chart(
        closer.sort_values("SALES", ascending=False),
        x="CLOSER_NAME",
        y="SALES",
    )
    st.dataframe(closer, use_container_width=True)

with tab_objections:
    st.subheader("Objections Faced")
    st.bar_chart(
        objections.sort_values("OBJECTION_COUNT", ascending=False),
        x="OBJECTION_CATEGORY",
        y="OBJECTION_COUNT",
    )
    st.dataframe(objections, use_container_width=True)
