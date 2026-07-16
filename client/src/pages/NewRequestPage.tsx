import { useMutation } from "@tanstack/react-query";
import { useState, type SyntheticEvent } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../api/apiClient";

export function NewRequestPage() {
  const navigate = useNavigate();
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [amount, setAmount] = useState("");
  const [department, setDepartment] = useState("");
  const [error, setError] = useState<string | null>(null);

  const createMutation = useMutation({
    mutationFn: () =>
      api.createPurchaseRequest({ title, description, amount: Number(amount), department }),
    onSuccess: (created) => {
      if (created.workflowInstanceId) navigate(`/instances/${created.workflowInstanceId}`);
      else navigate("/requests/mine");
    },
    onError: () => setError("Failed to submit the request."),
  });

  const handleSubmit = (event: SyntheticEvent) => {
    event.preventDefault();
    setError(null);
    createMutation.mutate();
  };

  return (
    <div>
      <h1>New Purchase Request</h1>
      <form className="card" onSubmit={handleSubmit} style={{ maxWidth: 480 }}>
        <label>
          Title
          <input value={title} onChange={(e) => setTitle(e.target.value)} required />
        </label>
        <label>
          Description
          <textarea rows={3} value={description} onChange={(e) => setDescription(e.target.value)} />
        </label>
        <label>
          Amount
          <input type="number" min="0" step="0.01" value={amount} onChange={(e) => setAmount(e.target.value)} required />
        </label>
        <label>
          Department
          <input value={department} onChange={(e) => setDepartment(e.target.value)} required />
        </label>
        {error && <p className="form-error">{error}</p>}
        <button className="primary" type="submit" disabled={createMutation.isPending}>
          {createMutation.isPending ? "Submitting..." : "Submit Request"}
        </button>
      </form>
    </div>
  );
}
