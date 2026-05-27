import {
    Document,
    Page,
    View,
    Text,
    Image,
    StyleSheet,
} from "@react-pdf/renderer";

export interface PDFItem {
    id: number;
    name: string;
    type?: string;
    price: string;
    imageDataUrl: string | null;
    variantCount: number;
}

interface AssignedItemsPDFProps {
    items: PDFItem[];
    agentName: string;
    tabLabel: string;
    generatedAt: string;
}

const styles = StyleSheet.create({
    page: {
        padding: 40,
        fontSize: 10,
        fontFamily: "Helvetica",
        color: "#1a1a1a",
    },
    header: {
        marginBottom: 24,
        borderBottomWidth: 2,
        borderBottomColor: "#000",
        paddingBottom: 12,
    },
    title: {
        fontSize: 18,
        fontWeight: "bold",
        marginBottom: 4,
    },
    subtitle: {
        fontSize: 10,
        color: "#666",
        marginBottom: 2,
    },
    table: {
        marginTop: 8,
    },
    tableHeader: {
        flexDirection: "row",
        borderBottomWidth: 1,
        borderBottomColor: "#ccc",
        paddingVertical: 6,
        fontWeight: "bold",
        fontSize: 9,
        color: "#444",
        textTransform: "uppercase",
    },
    tableRow: {
        flexDirection: "row",
        borderBottomWidth: 1,
        borderBottomColor: "#eee",
        paddingVertical: 6,
        alignItems: "center",
    },
    imageCell: {
        width: 40,
        paddingRight: 8,
    },
    itemImage: {
        width: 32,
        height: 32,
        objectFit: "cover",
        borderRadius: 4,
    },
    nameCell: {
        flex: 1,
        paddingRight: 8,
    },
    nameText: {
        fontSize: 10,
        fontWeight: "bold",
    },
    typeCell: {
        width: 60,
        paddingRight: 8,
    },
    typeText: {
        fontSize: 9,
        color: "#666",
        textTransform: "capitalize",
    },
    priceCell: {
        width: 60,
        paddingRight: 8,
        textAlign: "right",
    },
    priceText: {
        fontSize: 10,
    },
    variantsCell: {
        width: 50,
        textAlign: "center",
    },
    variantsText: {
        fontSize: 9,
        color: "#666",
    },
    footer: {
        marginTop: 20,
        paddingTop: 12,
        borderTopWidth: 1,
        borderTopColor: "#ccc",
        fontSize: 10,
        fontWeight: "bold",
        textAlign: "right",
    },
    imagePlaceholder: {
        width: 32,
        height: 32,
        backgroundColor: "#f0f0f0",
        borderRadius: 4,
    },
});

export default function AssignedItemsPDF({
    items,
    agentName,
    tabLabel,
    generatedAt,
}: AssignedItemsPDFProps) {
    return (
        <Document>
            <Page size="A4" style={styles.page}>
                <View style={styles.header}>
                    <Text style={styles.title}>Assigned Items Summary</Text>
                    <Text style={styles.subtitle}>Agent: {agentName}</Text>
                    <Text style={styles.subtitle}>{tabLabel}</Text>
                    <Text style={styles.subtitle}>
                        Generated: {generatedAt}
                    </Text>
                </View>

                <View style={styles.table}>
                    <View style={styles.tableHeader}>
                        <Text style={styles.imageCell}></Text>
                        <Text style={styles.nameCell}>Item</Text>
                        <Text style={styles.typeCell}>Type</Text>
                        <Text style={styles.priceCell}>Price</Text>
                        <Text style={styles.variantsCell}>Variants</Text>
                    </View>

                    {items.map((item, i) => (
                        <View style={styles.tableRow} key={item.id ?? i}>
                            <View style={styles.imageCell}>
                                {item.imageDataUrl ? (
                                    <Image
                                        src={item.imageDataUrl}
                                        style={styles.itemImage}
                                    />
                                ) : (
                                    <View style={styles.imagePlaceholder} />
                                )}
                            </View>
                            <View style={styles.nameCell}>
                                <Text style={styles.nameText}>{item.name}</Text>
                            </View>
                            <View style={styles.typeCell}>
                                <Text style={styles.typeText}>
                                    {item.type || "—"}
                                </Text>
                            </View>
                            <View style={styles.priceCell}>
                                <Text style={styles.priceText}>
                                    Rs. {item.price}
                                </Text>
                            </View>
                            <View style={styles.variantsCell}>
                                <Text style={styles.variantsText}>
                                    {item.variantCount}
                                </Text>
                            </View>
                        </View>
                    ))}
                </View>

                <View style={styles.footer}>
                    <Text>Total items: {items.length}</Text>
                </View>
            </Page>
        </Document>
    );
}
