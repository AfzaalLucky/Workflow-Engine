import { useMutation } from "@tanstack/react-query";
import { useState, type SyntheticEvent } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../api/apiClient";

export function NewLeasingCommissionPage() {
  const navigate = useNavigate();
  const [lesseeName, setLesseeName] = useState("");
  const [commissionAmount, setCommissionAmount] = useState("");
  const [branch, setBranch] = useState("");
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string | null>(null);

  const createMutation = useMutation({
    mutationFn: () =>
      api.createLeasingCommission({ lesseeName, commissionAmount: Number(commissionAmount), branch, notes }),
    onSuccess: (created) => {
      if (created.workflowInstanceId) navigate(`/instances/${created.workflowInstanceId}`);
      else navigate("/leasing-commissions/mine");
    },
    onError: () => setError("Failed to submit the leasing commission."),
  });

  const handleSubmit = (event: SyntheticEvent) => {
    event.preventDefault();
    setError(null);
    createMutation.mutate();
  };

  return (
    <div>
      <h1>New Leasing Commission</h1>
      <form className="card" onSubmit={handleSubmit} style={{ maxWidth: 480 }}>
        <label>
          Lessee Name
          <input value={lesseeName} onChange={(e) => setLesseeName(e.target.value)} required />
        </label>
        <label>
          Commission Amount
          <input
            type="number"
            min="0"
            step="0.01"
            value={commissionAmount}
            onChange={(e) => setCommissionAmount(e.target.value)}
            required
          />
        </label>
        <label>
          Branch
          <input value={branch} onChange={(e) => setBranch(e.target.value)} required />
        </label>
        <label>
          Notes
          <textarea rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} />
        </label>
        {error && <p className="form-error">{error}</p>}
        <button className="primary" type="submit" disabled={createMutation.isPending}>
          {createMutation.isPending ? "Submitting..." : "Submit Commission"}
        </button>
      </form>
    </div>
  );
}
