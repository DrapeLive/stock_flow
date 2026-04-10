import { Document, Page, Text, View, StyleSheet } from "@react-pdf/renderer";
import { InvoiceResponse } from "@/types/order";

// Styles
const styles = StyleSheet.create({
  page: {
    padding: 30,
    fontSize: 10,
    fontFamily: "Helvetica",
  },
  section: {
    marginBottom: 10,
  },
  header: {
    fontSize: 20,
    marginBottom: 10,
    fontWeight: "bold",
  },
  subText: {
    fontSize: 10,
    color: "gray",
  },
  table: {
    marginTop: 10,
    borderWidth: 1,
    borderColor: "#eee",
  },
  row: {
    flexDirection: "row",
    borderBottomWidth: 1,
    borderColor: "#eee",
    paddingVertical: 8,
    paddingHorizontal: 6,
    alignItems: "center",
  },
  col1: { width: "30%" },
  col2: { width: "14%", textAlign: "center" },
  col3: { width: "14%", textAlign: "center" },
  col4: { width: "14%", textAlign: "center" },
  col5: { width: "28%", textAlign: "right" },
  bold: { fontWeight: "bold" },
  itemName: { fontSize: 10 },
  itemPrice: { fontSize: 8, color: "gray" },
  qtyMain: { fontSize: 10, fontWeight: "bold" },
  qtySub: { fontSize: 7, color: "gray" },
  total: {
    marginTop: 15,
    textAlign: "right",
    fontSize: 14,
    fontWeight: "bold",
  },
});

// Helpers
const formatDate = (iso: string) => new Date(iso).toLocaleDateString("en-IN");

const formatTime = (iso: string) => new Date(iso).toLocaleTimeString("en-IN");

// Component
export const InvoicePDF = ({ invoice }: { invoice: InvoiceResponse }) => (
  <Document>
    <Page size="A4" style={styles.page}>
      {/* Header */}
      <Text style={styles.header}>
        Invoice #{invoice.id.toString().padStart(4, "0")}
      </Text>

      <View style={styles.section}>
        <Text>Date: {formatDate(invoice.created_at)} · Time: {formatTime(invoice.created_at)}</Text>
      </View>

      {/* Customer & Agent */}
      <View style={styles.section}>
        <Text><Text style={styles.bold}>Customer:</Text> {invoice.customer.name} · {invoice.customer.contact}</Text>
        <Text><Text style={styles.bold}>Agent:</Text> {invoice.agent.username} · {invoice.agent.contact}</Text>
      </View>

      {/* Items Table */}
      <View style={styles.table}>
        {/* Header Row */}
        <View style={[styles.row, styles.bold, { backgroundColor: "#333" }]}>
          <Text style={[styles.col1, { color: "white" }]}>Item</Text>
          <Text style={[styles.col2, { color: "white" }]}>Size</Text>
          <Text style={[styles.col3, { color: "white" }]}>Qty</Text>
          <Text style={[styles.col4, { color: "white" }]}>Packed</Text>
          <Text style={[styles.col5, { color: "white" }]}>Amount</Text>
        </View>

        {/* Data Rows */}
        {invoice.items.map((item, idx) => {
          const pieceCount = item.piece_count || 1;
          const totalPieces = item.quantity * pieceCount;
          const itemPrice = parseFloat(String(item.item_price)) || 0;
          const amount = itemPrice * item.quantity * pieceCount;
          const packed = item.packed_quantity || 0;
          const isEven = idx % 2 === 0;

          return (
            <View key={item.id} style={[styles.row, isEven ? { backgroundColor: "#fff" } : { backgroundColor: "#f9f9f9" }]}>
              <View style={styles.col1}>
                <Text style={styles.itemName}>{item.item_name}</Text>
                <Text style={styles.itemPrice}>₹{itemPrice.toLocaleString("en-IN")} / pc</Text>
              </View>
              <Text style={styles.col2}>{item.size_group}</Text>
              <View style={styles.col3}>
                <Text style={styles.qtyMain}>{item.quantity}</Text>
                <Text style={styles.qtySub}>({totalPieces} pcs)</Text>
              </View>
              <Text style={styles.col4}>{packed}/{totalPieces}</Text>
              <Text style={styles.col5}>₹{amount.toLocaleString("en-IN")}</Text>
            </View>
          );
        })}
      </View>

      {/* Total */}
      <Text style={styles.total}>
        Total: ₹{invoice.total_price.toLocaleString("en-IN")}
      </Text>
    </Page>
  </Document>
);
