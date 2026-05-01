import { Document, Page, Text, View, StyleSheet } from "@react-pdf/renderer";
import { InvoiceResponse } from "@/types/order";

// ── Styles ─────────────────────────────────────
const styles = StyleSheet.create({
  page: {
    padding: 32,
    fontSize: 10,
    fontFamily: "Helvetica",
  },

  header: {
    fontSize: 18,
    fontWeight: "bold",
    marginBottom: 4,
  },

  subText: {
    fontSize: 9,
    color: "#555",
  },

  section: {
    marginBottom: 12,
  },

  rowBetween: {
    flexDirection: "row",
    justifyContent: "space-between",
  },

  divider: {
    marginVertical: 10,
    borderBottomWidth: 1,
    borderColor: "#ddd",
  },

  // ── Table ──
  table: {
    marginTop: 10,
    borderWidth: 1,
    borderColor: "#ccc",
  },

  tableHeader: {
    flexDirection: "row",
    borderBottomWidth: 1,
    borderColor: "#ccc",
    backgroundColor: "#f2f2f2",
    paddingVertical: 6,
    paddingHorizontal: 6,
    fontWeight: "bold",
  },

  row: {
    flexDirection: "row",
    borderBottomWidth: 0.5,
    borderColor: "#e5e5e5",
    paddingVertical: 6,
    paddingHorizontal: 6,
    alignItems: "center",
  },

  colItem: { width: "42%" },
  colSize: { width: "14%", textAlign: "center" },
  colQty: { width: "18%", textAlign: "center" },
  colAmount: { width: "26%", textAlign: "right" },

  itemName: {
    fontSize: 10,
    fontWeight: "bold",
  },

  itemPrice: {
    fontSize: 8,
    color: "#666",
  },

  qtyMain: {
    fontSize: 10,
    fontWeight: "bold",
  },

  qtySub: {
    fontSize: 8,
    color: "#666",
  },

  totalBox: {
    marginTop: 16,
    alignSelf: "flex-end",
    width: 200,
  },

  totalRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 4,
  },

  totalFinal: {
    marginTop: 6,
    paddingTop: 6,
    borderTopWidth: 1,
    borderColor: "#000",
    fontSize: 12,
    fontWeight: "bold",
    flexDirection: "row",
    justifyContent: "space-between",
  },
});

// ── Helpers ─────────────────────────────────────
const formatDate = (iso: string) => new Date(iso).toLocaleDateString("en-IN");

const formatTime = (iso: string) => new Date(iso).toLocaleTimeString("en-IN");

// ── Component ─────────────────────────────────────
export const InvoicePDF = ({ invoice }: { invoice: InvoiceResponse }) => (
  <Document>
    <Page size="A4" style={styles.page}>
      {/* Header */}
      <View style={styles.section}>
        <Text style={styles.subText}>
          {formatDate(invoice.created_at)} · {formatTime(invoice.created_at)}
        </Text>
      </View>

      {/* Customer & Agent */}
      <View style={[styles.section, styles.rowBetween]}>
        <View>
          <Text style={styles.subText}>Bill To</Text>
          <Text style={{ fontWeight: "bold" }}>{invoice.customer.name}</Text>
          <Text style={styles.subText}>Customer ID: {invoice.customer.id}</Text>
        </View>

        <View style={{ alignItems: "flex-end" }}>
          <Text style={styles.subText}>Agent</Text>
          <Text>{invoice.agent.username}</Text>
        </View>
      </View>

      <View style={styles.divider} />

      {/* Table */}
      <View style={styles.table}>
        {/* Header */}
        <View style={styles.tableHeader}>
          <Text style={styles.colItem}>Item</Text>
          <Text style={styles.colSize}>Size</Text>
          <Text style={styles.colQty}>Sets</Text>
          <Text style={styles.colAmount}>Amount</Text>
        </View>

        {/* Rows */}
        {invoice.items.map((item, idx) => {
          const pieceCount = item.piece_count || 1;
          const totalPieces = item.quantity * pieceCount;
          const itemPrice = parseFloat(String(item.item_price)) || 0;
          const amount = itemPrice * item.quantity * pieceCount;

          return (
            <View key={item.id} style={styles.row}>
              <View style={styles.colItem}>
                <Text style={styles.itemName}>{item.item_name}</Text>
                <Text style={styles.itemPrice}>
                  Rs. {itemPrice.toLocaleString("en-IN")} / pc
                </Text>
              </View>

              <Text style={styles.colSize}>{item.size_group}</Text>

              <View style={styles.colQty}>
                <Text style={styles.qtyMain}>{item.quantity}</Text>
                <Text style={styles.qtySub}>
                  × {pieceCount} = {totalPieces}
                </Text>
              </View>

              <Text style={styles.colAmount}>
                Rs. {amount.toLocaleString("en-IN")}
              </Text>
            </View>
          );
        })}
      </View>

      {/* Totals */}
      <View style={styles.totalBox}>
        <View style={styles.totalRow}>
          <Text>Subtotal</Text>
          <Text>Rs. {invoice.total_price.toLocaleString("en-IN")}</Text>
        </View>

        <View style={styles.totalRow}>
          <Text>Tax</Text>
          <Text>—</Text>
        </View>

        <View style={styles.totalFinal}>
          <Text>Total</Text>
          <Text>Rs. {invoice.total_price.toLocaleString("en-IN")}</Text>
        </View>
      </View>
    </Page>
  </Document>
);
