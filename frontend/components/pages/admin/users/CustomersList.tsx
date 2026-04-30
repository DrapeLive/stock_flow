"use client";

import { Plus, Info } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { CustomerAllResponse } from "@/types/customer";
import { customerApi } from "@/lib/api/customer";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";

const CustomerList: React.FC = () => {
  const { isAuthenticated, business } = useAuth();

  const [data, setData] = useState<CustomerAllResponse>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");

  const router = useRouter();

  useEffect(() => {
    setLoading(true);

    const fetchData = async () => {
      try {
        const response = await customerApi.getAll();
        setData(response);
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [isAuthenticated]);

  const filteredData = data.filter((item) =>
    item.name.toLowerCase().includes(search.toLowerCase()),
  );

  const businessCustomers = business
    ? filteredData.filter((c) => c.has_business_orders === true)
    : filteredData;
  const otherCustomers = business
    ? filteredData.filter((c) => c.has_business_orders !== true)
    : [];

  if (loading) {
    return <h2 className="flex justify-center">Loading</h2>;
  }

  if (data.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[50vh] gap-4">
        <h2 className="text-xl font-bold text-gray-400">No Customers</h2>
        <StockFlowButton
          text="Add Customer"
          variant="filled"
          icon={<Plus className="size-4" />}
          onClick={() => router.push("/admin/users/customers/new")}
          className="shadow-lg shadow-primary/20 ring-1 ring-primary/10"
        />
      </div>
    );
  }

  const businessLabel = business ? business.charAt(0).toUpperCase() + business.slice(1) : "";

  const renderSection = (customers: typeof filteredData, header: string, count: number) => {
    if (customers.length === 0) return null;
    return (
      <>
        <div className="pt-2 flex justify-between items-center px-2 mb-4">
          <div className="flex flex-col">
            <h2 className="text-xl font-extrabold text-gray-900 leading-tight">
              {header}
            </h2>
            <div className="flex gap-2 items-center mt-1">
              <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">
                Total Active
              </span>
              <div className="bg-primary/10 text-primary rounded-full py-0.5 px-3 border border-primary/20">
                <span className="font-bold text-xs">{count}</span>
              </div>
            </div>
          </div>
        </div>

        <div className="px-2 mb-4">
          <input
            type="text"
            placeholder="Search customers..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-primary/30 text-sm"
          />
        </div>

        <div className="px-0 space-y-3 pb-20">
          {customers.map((item) => (
            <div
              key={item.id}
              onClick={() => router.push(`/admin/users/customers/${item.id}/`)}
              className="flex items-center gap-4 bg-white border border-gray-100 p-4 hover:border-primary/30 hover:shadow-md transition-all rounded-2xl group cursor-pointer active:scale-[0.98]"
            >
              <div className="w-12 h-12 rounded-xl bg-gray-50 flex items-center justify-center border border-gray-100 shadow-sm flex-shrink-0">
                <span className="text-xl font-black text-gray-400 opacity-30">
                  {item.name.charAt(0).toUpperCase()}
                </span>
              </div>

              <div className="flex-1 min-w-0">
                <h6 className="font-bold text-gray-900 text-[16px] truncate leading-tight">
                  {item.name}
                </h6>
                <p className="text-xs text-gray-400 truncate mt-1 leading-tight font-medium">
                  {item.address || "No address provided"}
                </p>

                <div className="flex items-center gap-2 mt-2">
                  <span className="text-[9px] bg-gray-50 text-gray-500 px-1.5 py-0.5 rounded-md uppercase font-bold tracking-tighter border border-gray-100">
                    {item.agent_name}
                  </span>
                  <span className="text-[9px] text-gray-300 font-bold uppercase tracking-widest">
                    Agent
                  </span>
                </div>
              </div>

              <div className="text-gray-200 group-hover:text-primary/30 transition-colors pl-2">
                <Info size={18} />
              </div>
            </div>
          ))}
        </div>
      </>
    );
  };

  if (!business) {
    return (
      <>
        <div className="pt-2 flex justify-between items-center px-2 mb-4">
          <div className="flex flex-col">
            <h2 className="text-xl font-extrabold text-gray-900 leading-tight">
              Customers
            </h2>
            <div className="flex gap-2 items-center mt-1">
              <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">
                Total Active
              </span>
              <div className="bg-primary/10 text-primary rounded-full py-0.5 px-3 border border-primary/20">
                <span className="font-bold text-xs">{data.length}</span>
              </div>
            </div>
          </div>

          <StockFlowButton
            text="Add Customer"
            variant="filled"
            icon={<Plus className="size-4" />}
            onClick={() => router.push("/admin/users/customers/new")}
            className="shadow-lg shadow-primary/20 ring-1 ring-primary/10"
          />
        </div>

        <div className="px-2 mb-4">
          <input
            type="text"
            placeholder="Search customers..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-primary/30 text-sm"
          />
        </div>

        {filteredData.length === 0 ? (
          <div className="flex justify-center mt-10">
            <h2 className="text-gray-400 font-semibold">No matching customers</h2>
          </div>
        ) : (
          <div className="px-0 space-y-3 pb-20">
            {filteredData.map((item) => (
              <div
                key={item.id}
                onClick={() => router.push(`/admin/users/customers/${item.id}/`)}
                className="flex items-center gap-4 bg-white border border-gray-100 p-4 hover:border-primary/30 hover:shadow-md transition-all rounded-2xl group cursor-pointer active:scale-[0.98]"
              >
                <div className="w-12 h-12 rounded-xl bg-gray-50 flex items-center justify-center border border-gray-100 shadow-sm flex-shrink-0">
                  <span className="text-xl font-black text-gray-400 opacity-30">
                    {item.name.charAt(0).toUpperCase()}
                  </span>
                </div>

                <div className="flex-1 min-w-0">
                  <h6 className="font-bold text-gray-900 text-[16px] truncate leading-tight">
                    {item.name}
                  </h6>
                  <p className="text-xs text-gray-400 truncate mt-1 leading-tight font-medium">
                    {item.address || "No address provided"}
                  </p>

                  <div className="flex items-center gap-2 mt-2">
                    <span className="text-[9px] bg-gray-50 text-gray-500 px-1.5 py-0.5 rounded-md uppercase font-bold tracking-tighter border border-gray-100">
                      {item.agent_name}
                    </span>
                    <span className="text-[9px] text-gray-300 font-bold uppercase tracking-widest">
                      Agent
                    </span>
                  </div>
                </div>

                <div className="text-gray-200 group-hover:text-primary/30 transition-colors pl-2">
                  <Info size={18} />
                </div>
              </div>
            ))}
          </div>
        )}
      </>
    );
  }

  return (
    <>
      <div className="pt-2 flex justify-between items-center px-2 mb-4">
        <div className="flex flex-col">
          <h2 className="text-xl font-extrabold text-gray-900 leading-tight">
            Customers
          </h2>
          <div className="flex gap-2 items-center mt-1">
            <span className="text-gray-400 text-[10px] font-bold uppercase tracking-wider">
              Total Active
            </span>
            <div className="bg-primary/10 text-primary rounded-full py-0.5 px-3 border border-primary/20">
              <span className="font-bold text-xs">{data.length}</span>
            </div>
          </div>
        </div>

        <StockFlowButton
          text="Add Customer"
          variant="filled"
          icon={<Plus className="size-4" />}
          onClick={() => router.push("/admin/users/customers/new")}
          className="shadow-lg shadow-primary/20 ring-1 ring-primary/10"
        />
      </div>

      <div className="px-2 mb-4">
        <input
          type="text"
          placeholder="Search customers..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-primary/30 text-sm"
        />
      </div>

      {renderSection(businessCustomers, `Customers — ${businessLabel}`, businessCustomers.length)}
      {renderSection(otherCustomers, "Other customers", otherCustomers.length)}

      {businessCustomers.length === 0 && otherCustomers.length === 0 && (
        <div className="flex justify-center mt-10">
          <h2 className="text-gray-400 font-semibold">No matching customers</h2>
        </div>
      )}
    </>
  );
};

export default CustomerList;
